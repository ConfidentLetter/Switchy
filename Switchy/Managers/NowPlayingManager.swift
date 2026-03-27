import Foundation
import AppKit

/// Per-source playback state so we can fall back between sources
private struct SourceState {
    var title: String = ""
    var artist: String = ""
    var album: String = ""
    var isPlaying: Bool = false
    var isAd: Bool = false
    var canSkip: Bool = true
    var duration: TimeInterval = 0
    var elapsed: TimeInterval = 0
    var lastUpdated: Date = .distantPast

    var hasTrack: Bool { !title.isEmpty }
}

class NowPlayingManager: ObservableObject {
    @Published var title: String = ""
    @Published var artist: String = ""
    @Published var album: String = ""
    @Published var isPlaying: Bool = false
    @Published var hasNowPlaying: Bool = false
    @Published var sourceName: String = ""
    @Published var musicAppRunning: Bool = false
    @Published var canSkipNext: Bool = true
    @Published var canSkipPrevious: Bool = true
    @Published var isAd: Bool = false
    @Published var duration: TimeInterval = 0
    @Published var elapsed: TimeInterval = 0

    // Per-source state tracking
    private var spotifyState = SourceState()
    private var appleMusicState = SourceState()
    private var activeSource: String = "" // "Spotify" or "Apple Music"

    private var refreshTimer: Timer?
    private var progressTimer: Timer?
    private var adPollTimer: Timer?
    /// Tracks when Spotify entered ad state via AppleScript detection
    private var adStartTime: Date?

    init() {
        observeDistributedNotifications()
        checkRunningApps()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkRunningApps()
        }
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard self.isPlaying else { return }

            if self.duration > 0 && !self.isAd {
                self.elapsed += 1.0
            }

            // While in ad state, tick the ad elapsed counter
            if self.isAd, let adStart = self.adStartTime {
                self.elapsed = Date().timeIntervalSince(adStart)
            }
        }
        // Poll Spotify via AppleScript every 2s for ad detection
        adPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.pollSpotifyForAd()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        progressTimer?.invalidate()
        adPollTimer?.invalidate()
        DistributedNotificationCenter.default().removeObserver(self)
    }

    // MARK: - AppleScript Ad Detection

    /// Poll Spotify via AppleScript to check if an ad is playing.
    /// Normal tracks return "spotify:track:xxxxx". Ads return empty, error, or non-track URIs.
    private func pollSpotifyForAd() {
        // Only poll when Spotify is the active source and is playing
        guard activeSource == "Spotify", isPlaying else { return }
        // Only poll if Spotify is actually running
        let spotifyRunning = NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.spotify.client"
        }
        guard spotifyRunning else { return }

        DispatchQueue.global(qos: .utility).async { [weak self] in
            let script = NSAppleScript(source: """
                tell application "Spotify"
                    if player state is playing then
                        return spotify url of current track
                    else
                        return "NOT_PLAYING"
                    end if
                end tell
                """)

            var errorInfo: NSDictionary?
            let result = script?.executeAndReturnError(&errorInfo)

            DispatchQueue.main.async {
                guard let self = self else { return }
                guard self.activeSource == "Spotify", self.isPlaying else { return }

                if let error = errorInfo {
                    // AppleScript error — likely an ad (Spotify refuses metadata)
                    print("[NowPlaying] AppleScript error: \(error)")
                    if !self.isAd {
                        self.enterAdState()
                    }
                    return
                }

                let uri = result?.stringValue ?? ""
                print("[NowPlaying] Spotify URI: \(uri)")

                if uri == "NOT_PLAYING" {
                    // Spotify says not playing — ignore
                    return
                }

                if uri.isEmpty || !uri.hasPrefix("spotify:track:") {
                    // Empty or non-track URI — this is an ad
                    if !self.isAd {
                        self.enterAdState()
                    }
                } else {
                    // Normal track — exit ad state if we were in one
                    if self.isAd {
                        self.exitAdState()
                    }
                }
            }
        }
    }

    /// Transition to ad state when AppleScript detects a non-track URI
    private func enterAdState() {
        isAd = true
        canSkipNext = false
        canSkipPrevious = false
        title = "Advertisement"
        artist = "Spotify"
        album = ""
        sourceName = "Spotify"
        duration = 0
        elapsed = 0
        adStartTime = Date()

        spotifyState.isAd = true
        spotifyState.canSkip = false
        spotifyState.title = "Advertisement"
        spotifyState.artist = "Spotify"
        spotifyState.album = ""
    }

    /// Exit ad state — the next Spotify notification will restore track info
    private func exitAdState() {
        isAd = false
        canSkipNext = true
        canSkipPrevious = true
        adStartTime = nil

        spotifyState.isAd = false
        spotifyState.canSkip = true
    }

    // MARK: - Distributed Notifications

    private func observeDistributedNotifications() {
        let dnc = DistributedNotificationCenter.default()

        dnc.addObserver(
            self,
            selector: #selector(spotifyNotification(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        dnc.addObserver(
            self,
            selector: #selector(appleMusicNotification(_:)),
            name: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil
        )
    }

    // MARK: - Spotify

    @objc private func spotifyNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        print("[NowPlaying] Spotify: \(info)")

        let state = info["Player State"] as? String ?? ""
        let trackName = info["Name"] as? String ?? ""
        let trackArtist = info["Artist"] as? String ?? ""
        let trackAlbum = info["Album"] as? String ?? ""
        let trackID = info["Track ID"] as? String ?? ""
        let dur = info["Duration"] as? Int ?? 0
        let position = info["Playback Position"] as? Double ?? 0

        // A real track notification with a proper track ID means we're out of the ad
        let isAdTrack = !trackID.isEmpty && !trackID.hasPrefix("spotify:track:")
        if !isAdTrack && isAd {
            exitAdState()
        }

        spotifyState.title = trackName
        spotifyState.artist = trackArtist
        spotifyState.album = trackAlbum
        spotifyState.isPlaying = (state == "Playing")
        spotifyState.isAd = isAdTrack
        spotifyState.canSkip = !isAdTrack
        spotifyState.duration = TimeInterval(dur) / 1000.0
        spotifyState.elapsed = position
        spotifyState.lastUpdated = Date()

        if state == "Stopped" {
            spotifyState.isPlaying = false
        }

        DispatchQueue.main.async {
            self.resolveActiveSource()
        }
    }

    // MARK: - Apple Music

    @objc private func appleMusicNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        print("[NowPlaying] Apple Music: \(info)")

        let state = info["Player State"] as? String ?? ""
        let trackName = info["Name"] as? String ?? ""
        let trackArtist = info["Artist"] as? String ?? ""
        let trackAlbum = info["Album"] as? String ?? ""
        let totalTime = info["Total Time"] as? Double ?? 0
        let position = info["Player Position"] as? Double ?? 0

        appleMusicState.title = trackName
        appleMusicState.artist = trackArtist
        appleMusicState.album = trackAlbum
        appleMusicState.isPlaying = (state == "Playing")
        appleMusicState.isAd = false
        appleMusicState.canSkip = true
        appleMusicState.duration = totalTime / 1000.0
        appleMusicState.elapsed = position
        appleMusicState.lastUpdated = Date()

        if state == "Stopped" || trackName.isEmpty {
            appleMusicState.isPlaying = false
        }

        DispatchQueue.main.async {
            self.resolveActiveSource()
        }
    }

    // MARK: - Source Resolution

    /// Decide which source to display. Priority:
    /// 1. A source that is currently playing
    /// 2. If both playing, most recently updated
    /// 3. If none playing, the most recently updated source that has a track
    private func resolveActiveSource() {
        let spotifyPlaying = spotifyState.isPlaying && spotifyState.hasTrack
        let applePlaying = appleMusicState.isPlaying && appleMusicState.hasTrack

        let chosen: (state: SourceState, name: String)?

        if spotifyPlaying && applePlaying {
            // Both playing — show whichever updated most recently
            if spotifyState.lastUpdated >= appleMusicState.lastUpdated {
                chosen = (spotifyState, "Spotify")
            } else {
                chosen = (appleMusicState, "Apple Music")
            }
        } else if spotifyPlaying {
            chosen = (spotifyState, "Spotify")
        } else if applePlaying {
            chosen = (appleMusicState, "Apple Music")
        } else if spotifyState.hasTrack && appleMusicState.hasTrack {
            // Neither playing — show most recently updated (paused state)
            if spotifyState.lastUpdated >= appleMusicState.lastUpdated {
                chosen = (spotifyState, "Spotify")
            } else {
                chosen = (appleMusicState, "Apple Music")
            }
        } else if spotifyState.hasTrack {
            chosen = (spotifyState, "Spotify")
        } else if appleMusicState.hasTrack {
            chosen = (appleMusicState, "Apple Music")
        } else {
            chosen = nil
        }

        if let chosen = chosen {
            title = chosen.state.title
            artist = chosen.state.artist
            album = chosen.state.album
            isPlaying = chosen.state.isPlaying
            isAd = chosen.state.isAd
            canSkipNext = chosen.state.canSkip
            canSkipPrevious = chosen.state.canSkip
            duration = chosen.state.duration
            elapsed = chosen.state.elapsed
            hasNowPlaying = true
            sourceName = chosen.name
            activeSource = chosen.name
        } else {
            title = ""
            artist = ""
            album = ""
            isPlaying = false
            hasNowPlaying = false
            sourceName = ""
            activeSource = ""
            isAd = false
            canSkipNext = true
            canSkipPrevious = true
            duration = 0
            elapsed = 0
        }
    }

    // MARK: - Playback Controls

    func togglePlayPause() {
        sendMediaKey(keyType: 16)
    }

    func nextTrack() {
        sendMediaKey(keyType: 17)
    }

    func previousTrack() {
        sendMediaKey(keyType: 18)
    }

    private func sendMediaKey(keyType: Int) {
        postMediaKeyEvent(keyType: keyType, down: true)
        postMediaKeyEvent(keyType: keyType, down: false)
    }

    private func postMediaKeyEvent(keyType: Int, down: Bool) {
        let rawFlag = down ? 0x0a : 0x0b
        let data1 = (keyType << 16) | (rawFlag << 8)
        let modifierFlags = down ? 0x0a00 : 0x0b00

        let event = NSEvent.otherEvent(
            with: .systemDefined,
            location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(modifierFlags)),
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            subtype: 8,
            data1: data1,
            data2: -1
        )
        event?.cgEvent?.post(tap: .cghidEventTap)
    }

    // MARK: - Helpers

    private func checkRunningApps() {
        let apps = NSWorkspace.shared.runningApplications
        let running = apps.contains { $0.bundleIdentifier == "com.spotify.client" }
            || apps.contains { $0.bundleIdentifier == "com.apple.Music" }
        DispatchQueue.main.async {
            self.musicAppRunning = running
        }
    }
}
