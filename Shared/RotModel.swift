import SwiftUI

/// How rotten the brain is. Rot is minutes / limit, mapped so that 100% limit == 100% rot.
struct RotSnapshot {
    var minutes: Int
    var limit: Int
    var streak: Int
    var mode: GuardMode
    var isShielded: Bool
    var unlockUntil: Date?
    var isMonitoring: Bool
    var challengesDone: Int
    var coachMessage: String?

    var ratio: Double { Double(minutes) / Double(max(limit, 1)) }
    /// 0...1 for visuals (saturates at 125% of the limit).
    var rot: Double { min(1, ratio / 1.25) }
    var rotPercent: Int { Int((min(ratio, 1.5) * 100).rounded()) }
    var stage: RotStage { RotStage(ratio: ratio) }
    var minutesLeft: Int { max(0, limit - minutes) }
    var isUnlocked: Bool { (unlockUntil ?? .distantPast) > Date() }

    static let placeholder = RotSnapshot(minutes: 37, limit: 60, streak: 3, mode: .gate,
                                         isShielded: true, unlockUntil: nil, isMonitoring: true,
                                         challengesDone: 12, coachMessage: nil)
    static let empty = RotSnapshot(minutes: 0, limit: 60, streak: 0, mode: .gate,
                                   isShielded: false, unlockUntil: nil, isMonitoring: false,
                                   challengesDone: 0, coachMessage: nil)
}

enum RotStage: Int, CaseIterable {
    case fresh, mushy, rotting, decayed, liquefied

    init(ratio: Double) {
        switch ratio {
        case ..<0.25: self = .fresh
        case ..<0.5: self = .mushy
        case ..<0.75: self = .rotting
        case ..<1.0: self = .decayed
        default: self = .liquefied
        }
    }

    var title: String {
        switch self {
        case .fresh: return "Fresh"
        case .mushy: return "Mushy"
        case .rotting: return "Rotting"
        case .decayed: return "Decayed"
        case .liquefied: return "Liquefied"
        }
    }

    var emoji: String {
        switch self {
        case .fresh: return "🧠"
        case .mushy: return "🫠"
        case .rotting: return "🤢"
        case .decayed: return "🧟"
        case .liquefied: return "☠️"
        }
    }

    var tagline: String {
        switch self {
        case .fresh: return "Crisp. Wrinkly. Dangerous."
        case .mushy: return "Getting soft around the edges."
        case .rotting: return "Something smells. It's you."
        case .decayed: return "Mostly goo at this point."
        case .liquefied: return "Terminal brainrot. Pour it out."
        }
    }

    /// Brain tint for this stage.
    var color: Color {
        switch self {
        case .fresh: return Theme.pink
        case .mushy: return Color(red: 0.93, green: 0.52, blue: 0.62)
        case .rotting: return Color(red: 0.71, green: 0.62, blue: 0.35)
        case .decayed: return Color(red: 0.46, green: 0.60, blue: 0.25)
        case .liquefied: return Color(red: 0.28, green: 0.45, blue: 0.18)
        }
    }
}

enum Theme {
    static let bg = Color(red: 0.043, green: 0.043, blue: 0.063)        // #0B0B10
    static let card = Color(red: 0.09, green: 0.09, blue: 0.125)        // #17171F
    static let cardStroke = Color.white.opacity(0.06)
    static let acid = Color(red: 0.776, green: 1.0, blue: 0.239)        // #C6FF3D
    static let pink = Color(red: 1.0, green: 0.42, blue: 0.62)          // #FF6B9E
    static let violet = Color(red: 0.545, green: 0.361, blue: 0.965)    // #8B5CF6
    static let slime = Color(red: 0.42, green: 0.78, blue: 0.20)
    static let textDim = Color.white.opacity(0.55)

    static func rotColor(_ rot: Double) -> Color {
        // pink -> yellow-brown -> slime green
        let stops: [(Double, (Double, Double, Double))] = [
            (0.0, (1.00, 0.42, 0.62)),
            (0.35, (0.96, 0.58, 0.45)),
            (0.6, (0.74, 0.66, 0.30)),
            (0.85, (0.46, 0.62, 0.22)),
            (1.0, (0.27, 0.44, 0.16))
        ]
        let t = min(max(rot, 0), 1)
        var lo = stops[0], hi = stops[stops.count - 1]
        for i in 0..<(stops.count - 1) where t >= stops[i].0 && t <= stops[i + 1].0 {
            lo = stops[i]; hi = stops[i + 1]
        }
        let span = max(hi.0 - lo.0, 0.0001)
        let f = (t - lo.0) / span
        return Color(red: lo.1.0 + (hi.1.0 - lo.1.0) * f,
                     green: lo.1.1 + (hi.1.1 - lo.1.1) * f,
                     blue: lo.1.2 + (hi.1.2 - lo.1.2) * f)
    }
}

extension Int {
    /// 95 -> "1h 35m", 40 -> "40m"
    var asDuration: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}
