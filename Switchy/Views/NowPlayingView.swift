import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var nowPlayingManager: NowPlayingManager

    var body: some View {
        VStack(spacing: 10) {
            if nowPlayingManager.hasNowPlaying {
                nowPlayingContent
            } else {
                emptyState
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Now Playing Content

    private var nowPlayingContent: some View {
        VStack(spacing: 8) {
            // Track info — full width, no artwork
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Text(nowPlayingManager.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)

                    if nowPlayingManager.isAd {
                        Text("AD")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.orange)
                            )
                    }
                }

                Text(nowPlayingManager.artist)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if !nowPlayingManager.album.isEmpty {
                    Text(nowPlayingManager.album)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                if !nowPlayingManager.sourceName.isEmpty {
                    Text(nowPlayingManager.sourceName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Transport controls
            transportControls

            // Progress timeline
            progressTimeline
        }
    }

    // MARK: - Progress Timeline

    private var progressTimeline: some View {
        VStack(spacing: 3) {
            if nowPlayingManager.isAd {
                // Ad: show elapsed time as a simple counter (no progress bar since duration is unknown)
                HStack {
                    Spacer()
                    Text(formatTime(nowPlayingManager.elapsed))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.orange)
                    Spacer()
                }
            } else if nowPlayingManager.duration > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 3)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(width: progressWidth(in: geo.size.width), height: 3)
                            .animation(.linear(duration: 1.0), value: nowPlayingManager.elapsed)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(formatTime(nowPlayingManager.elapsed))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(formatTime(nowPlayingManager.duration))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard nowPlayingManager.duration > 0 else { return 0 }
        let fraction = min(nowPlayingManager.elapsed / nowPlayingManager.duration, 1.0)
        return max(0, totalWidth * fraction)
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    // MARK: - Transport Controls

    private var transportControls: some View {
        HStack(spacing: 20) {
            TransportButton(
                icon: "backward.fill",
                size: 14,
                disabled: !nowPlayingManager.canSkipPrevious
            ) {
                nowPlayingManager.previousTrack()
            }

            TransportButton(
                icon: nowPlayingManager.isPlaying ? "pause.circle.fill" : "play.circle.fill",
                size: 28,
                disabled: false
            ) {
                nowPlayingManager.togglePlayPause()
            }

            TransportButton(
                icon: "forward.fill",
                size: 14,
                disabled: !nowPlayingManager.canSkipNext
            ) {
                nowPlayingManager.nextTrack()
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "hifispeaker.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)

            if nowPlayingManager.musicAppRunning {
                Text("Waiting for playback...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Play, pause, or skip a track to detect it")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Nothing Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Open Spotify or Apple Music to get started")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - Transport Button with press animation

private struct TransportButton: View {
    let icon: String
    let size: CGFloat
    let disabled: Bool
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            guard !disabled else { return }
            withAnimation(.easeIn(duration: 0.08)) {
                isPressed = true
            }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.easeOut(duration: 0.15)) {
                    isPressed = false
                }
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(disabled ? .secondary.opacity(0.3) : .primary)
                .scaleEffect(isPressed ? 0.8 : 1.0)
                .opacity(isPressed ? 0.6 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .animation(.easeOut(duration: 0.15), value: disabled)
    }
}
