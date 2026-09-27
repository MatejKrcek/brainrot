import Foundation

/// Shared identifiers used by the app and every extension.
enum AppGroup {
    static let id = "group.cz.krcek.brainhealth"
    static let urlScheme = "graymatter"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    /// False when the build isn't entitled to the App Group: the app, widget and extensions then each see
    /// their own defaults and the widget never updates. Fix: App Groups capability on the team / target.
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) != nil
    }
}

enum DeepLink {
    static let home = URL(string: "\(AppGroup.urlScheme)://home")!
    static let settings = URL(string: "\(AppGroup.urlScheme)://settings")!
}
