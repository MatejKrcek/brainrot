import Foundation

/// Websites the user typed in to keep out of, blocked all day in Safari, Chrome and every other browser
/// on the iPhone (see `WebsiteBlocker`). Stored as bare domains like "instagram.com".
enum BlockedSites {
    private static let key = "blockedSites"

    /// Screen Time's web filter takes at most 50 domains; each site uses two (bare + www).
    static let maxCount = 25

    static var all: [String] {
        get { AppGroup.defaults.stringArray(forKey: key) ?? [] }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }

    /// Turns whatever the user typed ("https://www.YouTube.com/shorts", "reddit.com") into a bare domain,
    /// or nil if it isn't one.
    static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, !s.contains(" ") else { return nil }
        if !s.contains("://") { s = "https://" + s }
        guard var host = URL(string: s)?.host, host.contains("."), !host.hasPrefix("."), !host.hasSuffix(".") else {
            return nil
        }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    /// Adds a site. Returns false when the input isn't a domain or the list is full.
    @discardableResult
    static func add(_ input: String) -> Bool {
        guard let domain = normalize(input) else { return false }
        var list = all
        if list.contains(domain) { return true }
        guard list.count < maxCount else { return false }
        list.append(domain)
        all = list
        return true
    }

    static func remove(_ domain: String) {
        all = all.filter { $0 != domain }
    }
}
