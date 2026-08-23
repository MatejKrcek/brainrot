import Foundation

/// Thin wrapper over the App Group UserDefaults that every target reads/writes.
enum SharedStore {
    private static var d: UserDefaults { AppGroup.defaults }

    enum Key {
        static let onboarded = "onboarded"
        static let dayKey = "dayKey"
        static let minutesToday = "minutesToday"
        static let dailyLimit = "dailyLimit"
        static let lockEnabled = "lockEnabled"
        static let unlockUntil = "unlockUntil"
        static let unlockMinutes = "unlockMinutes"
        static let isShielded = "isShielded"
        static let isMonitoring = "isMonitoring"
        static let history = "history"            // [String: Int] yyyy-MM-dd -> minutes
        static let demoMode = "demoMode"
        static let selectionCount = "selectionCount"
    }

    // MARK: - Day handling

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(for date: Date) -> String { dayFormatter.string(from: date) }
    static var todayKey: String { key(for: Date()) }

    /// Ensures counters belong to today. Archives yesterday into history if needed.
    @discardableResult
    static func rollOverIfNeeded(now: Date = Date()) -> Bool {
        let today = key(for: now)
        let stored = d.string(forKey: Key.dayKey)
        guard stored != today else { return false }
        if let stored {
            var h = history
            h[stored] = max(h[stored] ?? 0, d.integer(forKey: Key.minutesToday))
            history = h
        }
        d.set(today, forKey: Key.dayKey)
        d.set(0, forKey: Key.minutesToday)
        return true
    }

    // MARK: - Values

    static var onboarded: Bool {
        get { d.bool(forKey: Key.onboarded) }
        set { d.set(newValue, forKey: Key.onboarded) }
    }

    static var minutesToday: Int {
        get { rollOverIfNeeded(); return d.integer(forKey: Key.minutesToday) }
        set {
            rollOverIfNeeded()
            d.set(newValue, forKey: Key.minutesToday)
            var h = history
            h[todayKey] = newValue
            history = h
        }
    }

    static var dailyLimit: Int {
        get { let v = d.integer(forKey: Key.dailyLimit); return v == 0 ? 60 : v }
        set { d.set(newValue, forKey: Key.dailyLimit) }
    }

    static var lockEnabled: Bool {
        get { d.bool(forKey: Key.lockEnabled) }
        set { d.set(newValue, forKey: Key.lockEnabled) }
    }

    static var unlockMinutes: Int {
        get { let v = d.integer(forKey: Key.unlockMinutes); return v == 0 ? 15 : v }
        set { d.set(newValue, forKey: Key.unlockMinutes) }
    }

    static var unlockUntil: Date? {
        get { d.object(forKey: Key.unlockUntil) as? Date }
        set { d.set(newValue, forKey: Key.unlockUntil) }
    }

    static var isUnlocked: Bool {
        guard let u = unlockUntil else { return false }
        return u > Date()
    }

    static var isShielded: Bool {
        get { d.bool(forKey: Key.isShielded) }
        set { d.set(newValue, forKey: Key.isShielded) }
    }

    static var isMonitoring: Bool {
        get { d.bool(forKey: Key.isMonitoring) }
        set { d.set(newValue, forKey: Key.isMonitoring) }
    }

    static var selectionCount: Int {
        get { d.integer(forKey: Key.selectionCount) }
        set { d.set(newValue, forKey: Key.selectionCount) }
    }

    static var demoMode: Bool {
        get { d.bool(forKey: Key.demoMode) }
        set { d.set(newValue, forKey: Key.demoMode) }
    }

    static var history: [String: Int] {
        get {
            guard let data = d.data(forKey: Key.history),
                  let h = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
            return h
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { d.set(data, forKey: Key.history) }
        }
    }

    // MARK: - Snapshot for widgets / UI

    static func snapshot() -> RotSnapshot {
        rollOverIfNeeded()
        return RotSnapshot(
            minutes: d.integer(forKey: Key.minutesToday),
            limit: dailyLimit,
            lockEnabled: lockEnabled,
            isShielded: isShielded,
            unlockUntil: isUnlocked ? unlockUntil : nil,
            isMonitoring: isMonitoring
        )
    }

    static func resetAll() {
        for (k, _) in d.dictionaryRepresentation() { d.removeObject(forKey: k) }
    }
}
