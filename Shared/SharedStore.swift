import Foundation

/// Thin wrapper over the App Group UserDefaults that every target reads/writes.
enum SharedStore {
    private static var d: UserDefaults { AppGroup.defaults }

    enum Key {
        static let onboarded = "onboarded"
        static let dayKey = "dayKey"
        static let usedApps = "usedApps"
        static let monitorSchema = "monitorSchema"
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
        static let trackedApps = "trackedApps"          // [String] TrackedApp ids; missing = defaults
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
        d.removeObject(forKey: Key.usedApps)
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
        get { let v = d.integer(forKey: Key.unlockMinutes); return v == 0 ? 5 : v }
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

    /// Indices (into the ordered picked apps) of apps that reached a minute of use today. Written by the
    /// monitor extension; Home sizes the per-app report from the count. Cleared by the day rollover.
    static var usedAppsToday: Set<Int> {
        get { rollOverIfNeeded(); return Set(d.array(forKey: Key.usedApps) as? [Int] ?? []) }
        set { rollOverIfNeeded(); d.set(Array(newValue).sorted(), forKey: Key.usedApps) }
    }

    /// Which set of events the running daily schedule was registered with; bumped when the events change
    /// so an updated app re-registers once (see `ScreenTimeManager.ensureMonitoring`).
    static var monitorSchema: Int {
        get { d.integer(forKey: Key.monitorSchema) }
        set { d.set(newValue, forKey: Key.monitorSchema) }
    }

    static func markAppUsed(_ index: Int) {
        var used = usedAppsToday
        used.insert(index)
        usedAppsToday = used
    }

    /// Named apps the user chose. Defaults to TrackedApp.defaultIDs until the user changes it.
    static var trackedAppIDs: Set<String> {
        get {
            guard let ids = d.stringArray(forKey: Key.trackedApps) else { return TrackedApp.defaultIDs }
            return Set(ids)
        }
        set { d.set(Array(newValue).sorted(), forKey: Key.trackedApps) }
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

/// Bedtime: a second set of apps, picked separately from the tracked ones, fully blocked every night
/// (default 22:00 to 8:00). No unblock window: the system's repeating `DeviceActivity` schedule shields the
/// apps when the night starts and lifts it in the morning (see `BedtimeBlocker`).
enum Bedtime {
    static let selectionKey = "bedtimeSelection"

    private static var d: UserDefaults { AppGroup.defaults }
    private enum Key {
        static let enabled = "bedtimeEnabled"
        static let start = "bedtimeStart"          // minutes after midnight
        static let end = "bedtimeEnd"
        static let selectionCount = "bedtimeSelectionCount"
    }

    static let defaultStart = 22 * 60
    static let defaultEnd = 8 * 60
    /// DeviceActivity rejects intervals shorter than 15 minutes.
    static let minimumLength = 15

    static var enabled: Bool {
        get { d.bool(forKey: Key.enabled) }
        set { d.set(newValue, forKey: Key.enabled) }
    }

    static var startMinute: Int {
        get { d.object(forKey: Key.start) as? Int ?? defaultStart }
        set { d.set(newValue, forKey: Key.start) }
    }

    static var endMinute: Int {
        get { d.object(forKey: Key.end) as? Int ?? defaultEnd }
        set { d.set(newValue, forKey: Key.end) }
    }

    static var selectionCount: Int {
        get { d.integer(forKey: Key.selectionCount) }
        set { d.set(newValue, forKey: Key.selectionCount) }
    }

    /// Length of the window in minutes; a start after the end runs past midnight.
    static func length(start: Int, end: Int) -> Int { (end - start + 1440) % 1440 }

    /// Whether minute-of-day `m` falls in [start, end), wrapping past midnight when start > end.
    static func contains(_ m: Int, start: Int, end: Int) -> Bool {
        start < end ? (m >= start && m < end) : (m >= start || m < end)
    }

    /// True while the apps should be blocked: switched on, apps picked and the clock inside the window.
    static func isActive(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard enabled, selectionCount > 0, length(start: startMinute, end: endMinute) >= minimumLength else { return false }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return contains((c.hour ?? 0) * 60 + (c.minute ?? 0), start: startMinute, end: endMinute)
    }

    /// The next time the window ends, e.g. tomorrow 8:00.
    static func nextEnd(after date: Date = Date(), calendar: Calendar = .current) -> Date? {
        calendar.nextDate(after: date, matching: components(endMinute), matchingPolicy: .nextTime)
    }

    static func components(_ minute: Int) -> DateComponents { DateComponents(hour: minute / 60, minute: minute % 60) }

    /// "22:00" / "10:00 PM", in the user's locale.
    static func label(_ minute: Int) -> String {
        let date = Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}
