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
        VStack(spacing: 8) {
            Image(systemName: "keyboard.fill")
                .font(.system(size: 28))
                .foregroundColor(.orange)

            Text("Keyboard Locked")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            Text("Press  Space + Tab + R  to unlock")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(0.06))
                )

            Text("All keyboard input is currently blocked")
                .font(.caption2)
                .foregroundColor(.secondary)
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

            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                    .font(.system(size: 9))
                Text("Unlock with  Space + Tab + R")
                    .font(.system(size: 10))
            }
            .foregroundStyle(.tertiary)
        }
    }
}
