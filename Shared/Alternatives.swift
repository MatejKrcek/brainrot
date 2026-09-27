import Foundation

/// Things the scrolled minutes could have bought. Shown as "you could have called your parents 6×".
struct Alternative: Identifiable, Hashable {
    let id: String
    let text: String       // "called your parents"
    let minutes: Int
    let symbol: String

    static let all: [Alternative] = [
        Alternative(id: "read", text: "read a book for 10 minutes", minutes: 10, symbol: "book"),
        Alternative(id: "parents", text: "called your parents", minutes: 15, symbol: "phone"),
        Alternative(id: "sweet", text: "bought something sweet for your partner", minutes: 20, symbol: "gift"),
        Alternative(id: "walk", text: "taken a walk around the block", minutes: 20, symbol: "figure.walk"),
        Alternative(id: "friend", text: "texted an old friend", minutes: 5, symbol: "bubble.left"),
        Alternative(id: "coffee", text: "had a coffee with someone", minutes: 30, symbol: "cup.and.saucer"),
        Alternative(id: "workout", text: "done a workout", minutes: 30, symbol: "dumbbell"),
        Alternative(id: "nap", text: "taken a nap", minutes: 20, symbol: "bed.double"),
        Alternative(id: "cook", text: "cooked a proper dinner", minutes: 45, symbol: "frying.pan"),
        Alternative(id: "meditate", text: "meditated for 10 minutes", minutes: 10, symbol: "leaf"),
    ]

    /// How many times the alternative fits into `minutes`.
    func times(in minutes: Int) -> Int { minutes / max(self.minutes, 1) }

    /// "called your parents 6×"
    func line(for minutes: Int) -> String {
        let n = times(in: minutes)
        return n <= 1 ? text : "\(text) \(n)×"
    }

    /// Alternatives that fit at least once, ordered so the list feels varied (not just shortest first).
    static func fitting(_ minutes: Int, max count: Int = 4, day: Date = Date()) -> [Alternative] {
        let fits = all.filter { $0.times(in: minutes) >= 1 }
        guard !fits.isEmpty else { return [] }
        let offset = Calendar.current.ordinality(of: .day, in: .year, for: day) ?? 0
        let rotated = Array(fits[(offset % fits.count)...] + fits[..<(offset % fits.count)])
        return Array(rotated.prefix(count))
    }

    /// One line for the widget, rotating daily.
    static func headline(_ minutes: Int, day: Date = Date()) -> String? {
        guard let a = fitting(minutes, max: 1, day: day).first else { return nil }
        return "You could have " + a.line(for: minutes)
    }
}
