import Foundation

/// Named apps the user wants to count against their brain. Apple's Screen Time only hands out opaque
/// tokens through `FamilyActivityPicker`, so this list is the user's intent (and the demo-mode source
/// of truth); on a real device the picker still has to confirm the same apps once.
struct TrackedApp: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String

    static let customPrefix = "custom:"
    var isCustom: Bool { id.hasPrefix(Self.customPrefix) }

    static func custom(_ name: String) -> TrackedApp {
        TrackedApp(id: customPrefix + name.lowercased(), name: name, symbol: "app")
    }

    /// Built-in list plus whatever the user added by name.
    static var all: [TrackedApp] { builtIn + SharedStore.customAppNames.map(custom) }

    static let builtIn: [TrackedApp] = [
        TrackedApp(id: "tiktok", name: "TikTok", symbol: "music.note"),
        TrackedApp(id: "instagram", name: "Instagram", symbol: "camera"),
        TrackedApp(id: "x", name: "X / Twitter", symbol: "number"),
        TrackedApp(id: "linkedin", name: "LinkedIn", symbol: "briefcase"),
        TrackedApp(id: "threads", name: "Threads", symbol: "at"),
        TrackedApp(id: "youtube", name: "YouTube", symbol: "play.rectangle"),
        TrackedApp(id: "facebook", name: "Facebook", symbol: "person.2"),
        TrackedApp(id: "snapchat", name: "Snapchat", symbol: "bolt"),
        TrackedApp(id: "reddit", name: "Reddit", symbol: "bubble.left.and.bubble.right"),
    ]

    static let defaultIDs: Set<String> = ["tiktok", "instagram", "x", "linkedin", "threads"]

    static func named(_ ids: Set<String>) -> [TrackedApp] { all.filter { ids.contains($0.id) } }

    /// "TikTok, Instagram +3" for compact rows.
    static func summary(_ ids: Set<String>, max: Int = 2) -> String {
        let names = named(ids).map(\.name)
        if names.isEmpty { return "None" }
        if names.count <= max { return names.joined(separator: ", ") }
        return names.prefix(max).joined(separator: ", ") + " +\(names.count - max)"
    }
}
