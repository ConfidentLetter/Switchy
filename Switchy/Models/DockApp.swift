import Foundation
import AppKit

struct DockApp: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var bundleIdentifier: String
    var path: String

    var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: path)
    }

    // Codable conformance excluding the computed icon
    enum CodingKeys: String, CodingKey {
        case id, name, bundleIdentifier, path
    }

    // Hashable conformance excluding the computed icon
    static func == (lhs: DockApp, rhs: DockApp) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
