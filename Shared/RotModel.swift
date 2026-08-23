import SwiftUI

/// Rot is minutes / limit: 100% of the limit = 100% rot; visuals saturate at 125%.
struct RotSnapshot {
    var minutes: Int
    var limit: Int
    var lockEnabled: Bool
    var isShielded: Bool
    var unlockUntil: Date?
    var isMonitoring: Bool

    var ratio: Double { Double(minutes) / Double(max(limit, 1)) }
    var rot: Double { min(1, ratio / 1.25) }
    var rotPercent: Int { Int((min(ratio, 1.5) * 100).rounded()) }
    var stage: RotStage { RotStage(ratio: ratio) }
    var minutesLeft: Int { max(0, limit - minutes) }
    /// Headline metric: 100% at zero usage, 0% at the limit.
    var healthPercent: Int { max(0, 100 - Int((ratio * 100).rounded())) }
    var isUnlocked: Bool { (unlockUntil ?? .distantPast) > Date() }

    static let placeholder = RotSnapshot(minutes: 22, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: true)
    static let empty = RotSnapshot(minutes: 0, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: false)
}

enum RotStage: Int, CaseIterable {
    case sharp, foggy, fading, failing, flatlined

    init(ratio: Double) {
        switch ratio {
        case ..<0.25: self = .sharp
        case ..<0.5: self = .foggy
        case ..<0.75: self = .fading
        case ..<1.0: self = .failing
        default: self = .flatlined
        }
    }

    var title: String {
        switch self {
        case .sharp: return "Sharp"
        case .foggy: return "Foggy"
        case .fading: return "Fading"
        case .failing: return "Failing"
        case .flatlined: return "Flatlined"
        }
    }

    var summary: String {
        switch self {
        case .sharp: return "Rested and responsive."
        case .foggy: return "Attention is starting to slip."
        case .fading: return "Focus is breaking down."
        case .failing: return "Running on fumes."
        case .flatlined: return "Limit reached. Resets at midnight."
        }
    }
}

enum Theme {
    /// Text/progress tint derived from the brain palette at a given rot.
    static func rotColor(_ rot: Double) -> Color { BrainPalette.base(rot).lighter(0.1).color }
}

extension Int {
    /// 95 -> "1 h 35 min", 40 -> "40 min"
    var asDuration: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }
    /// Compact: 95 -> "1h 35m"
    var asShortDuration: String {
        let h = self / 60, m = self % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}
