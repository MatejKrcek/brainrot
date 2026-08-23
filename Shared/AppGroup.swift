import Foundation

/// Shared identifiers used by the app and every extension.
enum AppGroup {
    static let id = "group.com.matejkrcek.graymatter"
    static let urlScheme = "graymatter"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

enum DeepLink {
    static let home = URL(string: "\(AppGroup.urlScheme)://home")!
    static let settings = URL(string: "\(AppGroup.urlScheme)://settings")!
}
