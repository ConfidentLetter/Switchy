import SwiftUI

struct KeyboardCleanerView: View {
    @EnvironmentObject var keyboardCleanerManager: KeyboardCleanerManager

    var body: some View {
        VStack(spacing: 12) {
            if !keyboardCleanerManager.hasAccessibilityPermission {
                accessibilityWarning
            }

            if keyboardCleanerManager.isActive {
                activeState
            } else {
                inactiveState
            }
        }
        .padding(.bottom, 8)
        .onAppear {
            keyboardCleanerManager.checkAccessibilityPermission()
            if !keyboardCleanerManager.hasAccessibilityPermission {
                keyboardCleanerManager.startPollingAccessibilityPermission()
            }
        }
        .onDisappear {
            keyboardCleanerManager.stopPollingAccessibilityPermission()
        }
    }

    // MARK: - States

    private var accessibilityWarning: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                Text("Accessibility Permission Required")
                    .font(.system(size: 11, weight: .medium))
            }

            Text("Switchy needs Accessibility access to block keyboard input during cleaning.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Grant Permission") {
                keyboardCleanerManager.requestAccessibilityPermission()
            }
            .font(.system(size: 11))
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.yellow.opacity(0.08))
        )
    }

    private var activeState: some View {
        VStack(spacing: 10) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)

            Text("Keyboard Locked")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            Text("All keyboard input is currently blocked")
                .font(.caption2)
                .foregroundColor(.secondary)

            Button {
                keyboardCleanerManager.deactivate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 11))
                    Text("Unlock Keyboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .tint(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var inactiveState: some View {
        VStack(spacing: 10) {
            VStack(spacing: 4) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)

                Text("Keyboard Cleaner")
                    .font(.system(size: 13, weight: .medium))

                Text("Lock your keyboard to safely clean it without triggering accidental inputs.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                keyboardCleanerManager.activate()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11))
                    Text("Lock Keyboard")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(!keyboardCleanerManager.hasAccessibilityPermission)
        }
    }
}
