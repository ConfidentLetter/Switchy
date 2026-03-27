import SwiftUI

@main
struct SwitchyApp: App {
    @StateObject private var audioManager = AudioManager()
    @StateObject private var dockManager = DockManager()
    @StateObject private var nowPlayingManager = NowPlayingManager()
    @StateObject private var keyboardCleanerManager = KeyboardCleanerManager()

    var body: some Scene {
        MenuBarExtra("Switchy", systemImage: "power.circle.fill") {
            SwitchyContentView()
                .environmentObject(audioManager)
                .environmentObject(dockManager)
                .environmentObject(nowPlayingManager)
                .environmentObject(keyboardCleanerManager)
        }
        .menuBarExtraStyle(.window)
    }
}
