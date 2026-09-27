import Foundation

/// What today's scrolled minutes could have been instead. One is shown at a time, as a quote,
/// and a different one comes up each time the app is opened.
struct Alternative: Identifiable {
    let id: String
    let minMinutes: Int
    let symbol: String
    let make: (Int) -> String

    /// "1 h 35 min" for templates.
    private static func t(_ m: Int) -> String { m.asDuration }

    static let all: [Alternative] = [
        Alternative(id: "ai", minMinutes: 20, symbol: "brain") { "You could have spent \(t($0)) learning AI." },
        Alternative(id: "run", minMinutes: 15, symbol: "figure.run") { "You could have run about \(km($0, minPerKm: 6.5)) km." },
        Alternative(id: "friend", minMinutes: 20, symbol: "person.2") { "You could have spent \(t($0)) with a friend." },
        Alternative(id: "gym", minMinutes: 30, symbol: "dumbbell") { m in
            m >= 90 ? "You could have done \(m / 45) full gym sessions." : "You could have gone to the gym." },
        Alternative(id: "read", minMinutes: 10, symbol: "book") { "You could have read about \($0 * 2 / 3) pages of a book." },
        Alternative(id: "parents", minMinutes: 15, symbol: "phone") { m in
            m >= 30 ? "You could have called your parents \(m / 15) times." : "You could have called your parents." },
        Alternative(id: "walk", minMinutes: 15, symbol: "figure.walk") { "You could have walked about \(km($0, minPerKm: 12)) km outside." },
        Alternative(id: "sweet", minMinutes: 20, symbol: "gift") { _ in "You could have gone out and bought something sweet for your partner." },
        Alternative(id: "cook", minMinutes: 45, symbol: "frying.pan") { _ in "You could have cooked a proper dinner and eaten it slowly." },
        Alternative(id: "nap", minMinutes: 20, symbol: "bed.double") { "You could have taken a \(t(min($0, 90))) nap." },
        Alternative(id: "language", minMinutes: 10, symbol: "character.book.closed") { "You could have learned \($0 / 2) new words in a language." },
        Alternative(id: "meditate", minMinutes: 10, symbol: "leaf") { "You could have sat in silence for \(t($0)) and felt better for it." },
        Alternative(id: "music", minMinutes: 30, symbol: "music.note") { "You could have listened to \($0 / 40 + 1) whole albums, start to finish." },
        Alternative(id: "sleep", minMinutes: 60, symbol: "moon.zzz") { "You could have slept \(t($0)) longer." },
    ]

    private static func km(_ minutes: Int, minPerKm: Double) -> String {
        let v = Double(minutes) / minPerKm
        return v < 10 ? String(format: "%.1f", v) : String(Int(v.rounded()))
    }

    func text(for minutes: Int) -> String { make(minutes) }

    static func fitting(_ minutes: Int) -> [Alternative] { all.filter { minutes >= $0.minMinutes } }

    /// A random alternative that fits `minutes`, avoiding `except` so consecutive opens differ.
    static func random(for minutes: Int, except: String? = nil) -> Alternative? {
        var pool = fitting(minutes)
        if pool.count > 1, let except { pool.removeAll { $0.id == except } }
        return pool.randomElement()
    }

    /// Deterministic pick for the widget: changes daily.
    static func daily(for minutes: Int, day: Date = Date()) -> Alternative? {
        let pool = fitting(minutes)
        guard !pool.isEmpty else { return nil }
        let n = Calendar.current.ordinality(of: .day, in: .year, for: day) ?? 0
        return pool[n % pool.count]
    }

    static func headline(_ minutes: Int, day: Date = Date()) -> String? {
        daily(for: minutes, day: day)?.text(for: minutes)
    }
}
