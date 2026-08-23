import Foundation

/// Blocking behaviour.
enum GuardMode: String, Codable, CaseIterable, Identifiable {
    /// Apps are always locked; every open requires a challenge (15 min window).
    case gate
    /// Apps are free until the daily limit, then locked (challenges buy extra time).
    case limit

    var id: String { rawValue }
    var title: String {
        switch self {
        case .gate: return "Gatekeeper"
        case .limit: return "Daily limit"
        }
    }
    var subtitle: String {
        switch self {
        case .gate: return "Every open costs a challenge. Hard mode."
        case .limit: return "Scroll freely until the limit, then it's locked."
        }
    }
}

enum ChallengeKind: String, Codable, CaseIterable, Identifiable {
    case random, breathe, math, type, hold, walk

    var id: String { rawValue }
    var title: String {
        switch self {
        case .random: return "Surprise me"
        case .breathe: return "Breathe"
        case .math: return "Mental math"
        case .type: return "Type the vow"
        case .hold: return "Hold still"
        case .walk: return "Walk it off"
        }
    }
    var symbol: String {
        switch self {
        case .random: return "dice"
        case .breathe: return "wind"
        case .math: return "function"
        case .type: return "keyboard"
        case .hold: return "hand.raised"
        case .walk: return "figure.walk"
        }
    }
    var blurb: String {
        switch self {
        case .random: return "A different challenge every time."
        case .breathe: return "3 rounds of 4-7-8 breathing."
        case .math: return "5 quick arithmetic questions."
        case .type: return "Type a commitment sentence, no typos."
        case .hold: return "Hold a button for 30 seconds. Release = restart."
        case .walk: return "Walk 60 steps. Your legs have to earn it."
        }
    }
}

/// Thin wrapper over the App Group UserDefaults that every target reads/writes.
enum SharedStore {
    private static var d: UserDefaults { AppGroup.defaults }

    enum Key {
        static let onboarded = "onboarded"
        static let dayKey = "dayKey"
        static let minutesToday = "minutesToday"
        static let dailyLimit = "dailyLimit"
        static let mode = "mode"
        static let unlockUntil = "unlockUntil"
        static let unlockMinutes = "unlockMinutes"
        static let isShielded = "isShielded"
        static let isMonitoring = "isMonitoring"
        static let history = "history"            // [String: Int] yyyy-MM-dd -> minutes
        static let streak = "streak"
        static let lastStreakDay = "lastStreakDay"
        static let challengeKind = "challengeKind"
        static let challengesDone = "challengesDone"
        static let coachMessage = "coachMessage"
        static let coachDate = "coachDate"
        static let coachLanguage = "coachLanguage"
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
            updateStreak(closingDay: stored, minutes: h[stored] ?? 0)
        }
        d.set(today, forKey: Key.dayKey)
        d.set(0, forKey: Key.minutesToday)
        return true
    }

    // MARK: - Core values

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

    static var mode: GuardMode {
        get { GuardMode(rawValue: d.string(forKey: Key.mode) ?? "") ?? .gate }
        set { d.set(newValue.rawValue, forKey: Key.mode) }
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

    static var challengeKind: ChallengeKind {
        get { ChallengeKind(rawValue: d.string(forKey: Key.challengeKind) ?? "") ?? .random }
        set { d.set(newValue.rawValue, forKey: Key.challengeKind) }
    }

    static var challengesDone: Int {
        get { d.integer(forKey: Key.challengesDone) }
        set { d.set(newValue, forKey: Key.challengesDone) }
    }

    static var demoMode: Bool {
        get { d.bool(forKey: Key.demoMode) }
        set { d.set(newValue, forKey: Key.demoMode) }
    }

    static var coachLanguage: String {
        get { d.string(forKey: Key.coachLanguage) ?? "cs" }
        set { d.set(newValue, forKey: Key.coachLanguage) }
    }

    static var coachMessage: String? {
        get { d.string(forKey: Key.coachMessage) }
        set { d.set(newValue, forKey: Key.coachMessage) }
    }

    static var coachDate: Date? {
        get { d.object(forKey: Key.coachDate) as? Date }
        set { d.set(newValue, forKey: Key.coachDate) }
    }

    // MARK: - History & streak

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

    static var streak: Int {
        get { d.integer(forKey: Key.streak) }
        set { d.set(newValue, forKey: Key.streak) }
    }

    private static func updateStreak(closingDay: String, minutes: Int) {
        let last = d.string(forKey: Key.lastStreakDay)
        guard last != closingDay else { return }
        if minutes <= dailyLimit { streak += 1 } else { streak = 0 }
        d.set(closingDay, forKey: Key.lastStreakDay)
    }

    /// Last `days` days including today, oldest first.
    static func recentDays(_ days: Int = 7, now: Date = Date()) -> [(day: Date, minutes: Int)] {
        rollOverIfNeeded(now: now)
        let h = history
        let cal = Calendar.current
        return (0..<days).reversed().compactMap { offset in
            guard let day = cal.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let k = key(for: day)
            let m = offset == 0 ? d.integer(forKey: Key.minutesToday) : (h[k] ?? 0)
            return (cal.startOfDay(for: day), m)
        }
    }

    // MARK: - Snapshot for widgets / UI

    static func snapshot() -> RotSnapshot {
        rollOverIfNeeded()
        return RotSnapshot(
            minutes: d.integer(forKey: Key.minutesToday),
            limit: dailyLimit,
            streak: streak,
            mode: mode,
            isShielded: isShielded,
            unlockUntil: isUnlocked ? unlockUntil : nil,
            isMonitoring: isMonitoring,
            challengesDone: challengesDone,
            coachMessage: coachMessage
        )
    }

    static func resetAll() {
        for (k, _) in d.dictionaryRepresentation() { d.removeObject(forKey: k) }
    }
}
