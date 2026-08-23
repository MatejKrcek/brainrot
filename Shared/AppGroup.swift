import Foundation

/// Shared identifiers used by the app and every extension.
enum AppGroup {
    static let id = "group.com.matejkrcek.brainrot"
    static let urlScheme = "brainrot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

enum DeepLink {
    static let home = URL(string: "\(AppGroup.urlScheme)://home")!
    static let challenge = URL(string: "\(AppGroup.urlScheme)://challenge")!
    static let coach = URL(string: "\(AppGroup.urlScheme)://coach")!
}
