import Foundation
import AppKit
import SwiftUI

class DockManager: ObservableObject {
    @Published var apps: [DockApp] = []

    private let storageKey = "switchyDockApps"

    init() {
        load()
    }

    // MARK: - Persistence

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DockApp].self, from: data)
        else { return }
        apps = decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(apps) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    // MARK: - Actions

    func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Choose an Application"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let bundle = Bundle(url: url)
        let name = bundle?.infoDictionary?["CFBundleName"] as? String
            ?? bundle?.infoDictionary?["CFBundleDisplayName"] as? String
            ?? url.deletingPathExtension().lastPathComponent
        let bundleID = bundle?.bundleIdentifier ?? ""

        // Avoid duplicates
        guard !apps.contains(where: { $0.path == url.path }) else { return }

        let app = DockApp(
            id: UUID(),
            name: name,
            bundleIdentifier: bundleID,
            path: url.path
        )
        apps.append(app)
        save()
    }

    func removeApp(_ app: DockApp) {
        apps.removeAll { $0.id == app.id }
        save()
    }

    func launchApp(_ app: DockApp) {
        let url = URL(fileURLWithPath: app.path)
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error = error {
                print("Failed to launch \(app.name): \(error.localizedDescription)")
            }
        }
    }

    func moveApp(from source: IndexSet, to destination: Int) {
        apps.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
