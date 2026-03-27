import SwiftUI
import CoreAudio

struct AudioDevicesView: View {
    @EnvironmentObject var audioManager: AudioManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Output devices
                DeviceSection(
                    title: "Output",
                    icon: "speaker.wave.2.fill",
                    devices: audioManager.outputDevices,
                    currentDeviceID: audioManager.currentOutputDeviceID,
                    onSelect: { audioManager.setDefaultOutput($0.id) }
                )

                if !audioManager.inputDevices.isEmpty {
                    Divider()

                    // Input devices
                    DeviceSection(
                        title: "Input",
                        icon: "mic.fill",
                        devices: audioManager.inputDevices,
                        currentDeviceID: audioManager.currentInputDeviceID,
                        onSelect: { audioManager.setDefaultInput($0.id) }
                    )
                }
            }
            .padding(.bottom, 8)
        }
    }
}

private struct DeviceSection: View {
    let title: String
    let icon: String
    let devices: [AudioDevice]
    let currentDeviceID: AudioDeviceID
    let onSelect: (AudioDevice) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)

            if devices.isEmpty {
                Text("No devices found")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(devices) { device in
                        DeviceRow(
                            device: device,
                            isSelected: device.id == currentDeviceID,
                            onSelect: { onSelect(device) }
                        )
                    }
                }
            }
        }
    }
}

private struct DeviceRow: View {
    let device: AudioDevice
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 12))
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                Text(device.name)
                    .font(.system(size: 13))
                    .lineLimit(1)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
