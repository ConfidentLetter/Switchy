import SwiftUI

enum SwitchyTab: String, CaseIterable {
    case audio
    case dock
    case keyboard
    case media

    var icon: String {
        switch self {
        case .audio: return "speaker.wave.2.fill"
        case .dock: return "square.grid.2x2"
        case .keyboard: return "keyboard.fill"
        case .media: return "hifispeaker.fill"
        }
    }

    var label: String {
        switch self {
        case .audio: return "Audio"
        case .dock: return "Dock"
        case .keyboard: return "Keyboard"
        case .media: return "Media"
        }
    }
}

struct SwitchyContentView: View {
    @State private var selectedTab: SwitchyTab = .audio

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            HStack(spacing: 4) {
                ForEach(SwitchyTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 14))
                            Text(tab.label)
                                .font(.system(size: 9, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(selectedTab == tab ? .accentColor : .secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 10)

            Divider()
                .padding(.vertical, 6)

            // Content area
            Group {
                switch selectedTab {
                case .audio:
                    AudioDevicesView()
                case .dock:
                    AppDockView()
                case .keyboard:
                    KeyboardCleanerView()
                case .media:
                    NowPlayingView()
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            Divider()

            // Footer
            HStack {
                Text("Switchy")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(width: 300)
    }
}
