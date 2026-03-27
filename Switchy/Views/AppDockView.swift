import SwiftUI

struct AppDockView: View {
    @EnvironmentObject var dockManager: DockManager

    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 8)
    ]

    var body: some View {
        VStack(spacing: 8) {
            if dockManager.apps.isEmpty {
                emptyState
            } else {
                appGrid
            }

            addButton
        }
        .padding(.bottom, 8)
    }

    // MARK: - Components

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("No apps added yet")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Add your favorite apps for quick access")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private var appGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(dockManager.apps) { app in
                AppIcon(app: app)
                    .contextMenu {
                        Button(role: .destructive) {
                            dockManager.removeApp(app)
                        } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
            }
        }
    }

    private var addButton: some View {
        Button {
            dockManager.addApp()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 12))
                Text("Add App")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.accentColor)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - App Icon

private struct AppIcon: View {
    let app: DockApp
    @EnvironmentObject var dockManager: DockManager

    var body: some View {
        Button {
            dockManager.launchApp(app)
        } label: {
            VStack(spacing: 3) {
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .frame(width: 36, height: 36)
                }

                Text(app.name)
                    .font(.system(size: 9))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 56)
        }
        .buttonStyle(.plain)
    }
}
