import Foundation
import DeviceActivity
import ManagedSettings

extension DeviceActivityName {
    /// Repeating all-day schedule that counts usage of the selected apps.
    static let daily = DeviceActivityName("graymatter.daily")
    /// One-shot schedule for an unlock window earned by a challenge.
    static let unlock = DeviceActivityName("graymatter.unlock")
}

extension DeviceActivityEvent.Name {
    static let tickPrefix = "graymatter.tick."
    static func tick(_ minutes: Int) -> DeviceActivityEvent.Name { .init(tickPrefix + String(minutes)) }
    var tickMinutes: Int? {
        guard rawValue.hasPrefix(Self.tickPrefix) else { return nil }
        return Int(rawValue.dropFirst(Self.tickPrefix.count))
    }
}

extension ManagedSettingsStore.Name {
    static let graymatter = ManagedSettingsStore.Name("graymatter")
}

/// Minute marks at which the monitor extension is woken. Minute resolution for the first
/// 90 minutes, then every 5 minutes up to 6 hours.
enum Ticks {
    static var all: [Int] {
        Array(1...90) + stride(from: 95, through: 360, by: 5).map { $0 }
    }
}
