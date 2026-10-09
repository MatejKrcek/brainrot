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

/// The shield's Unblock button leaves this timestamp and then opens Brain Health (iOS 26.5+) or posts a
/// notification that does; opening the app shortly after, by either route or by hand, offers the unblock.
enum UnblockRequest {
    static let key = "pendingUnlockRequest"
    static let notificationID = "unblock-request"
    static let ttl: TimeInterval = 10 * 60
}

enum DeepLink {
    static let home = URL(string: "\(AppGroup.urlScheme)://home")!
    static let settings = URL(string: "\(AppGroup.urlScheme)://settings")!
}
