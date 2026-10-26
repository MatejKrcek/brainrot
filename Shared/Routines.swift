import Foundation

/// A reminder at a set time on chosen days ("Time to read" at 23:00), optionally blocking apps and websites
/// from that time until `endHour:endMinute`. The notification is scheduled by the app (`RoutineNotifications`);
/// the block is a repeating DeviceActivity schedule the monitor extension turns into a shield (`RoutineBlocker`).
struct Routine: Codable, Identifiable, Equatable {
    var id = UUID()
    var title = "Time to read"
    var message = "Put the phone down and read a few pages."
    var hour = 23
    var minute = 0
    /// Calendar weekdays, 1 = Sunday … 7 = Saturday.
    var weekdays: Set<Int> = Set(1...7)
    var enabled = true
    var blocks = true
    var endHour = 7
    var endMinute = 0
    /// Bare domains like "youtube.com", blocked in every browser during the window.
    var sites: [String] = []

    /// The system won't run a DeviceActivity interval shorter than this.
    static let minimumBlockMinutes = 15

    var startMinuteOfDay: Int { hour * 60 + minute }
    var endMinuteOfDay: Int { endHour * 60 + endMinute }

    /// Length of the block window; a window that ends at or before its start runs past midnight.
    var blockMinutes: Int {
        let len = (endMinuteOfDay - startMinuteOfDay + 1440) % 1440
        return len == 0 ? 1440 : len
    }

    var isBlockValid: Bool { blockMinutes >= Self.minimumBlockMinutes && blockMinutes < 1440 }

    /// Whether the routine starts on the day `date` falls on.
    func runs(on date: Date, calendar: Calendar = .current) -> Bool {
        enabled && weekdays.contains(calendar.component(.weekday, from: date))
    }

    /// Whether the block window covers `date`. A window past midnight belongs to the day it started.
    func isBlocking(at date: Date, calendar: Calendar = .current) -> Bool {
        guard enabled, blocks, isBlockValid else { return false }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let now = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        let start = startMinuteOfDay, end = endMinuteOfDay
        if start < end { return now >= start && now < end && runs(on: date, calendar: calendar) }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return (now >= start && runs(on: date, calendar: calendar))
            || (now < end && runs(on: yesterday, calendar: calendar))
    }

    var startText: String { Self.timeText(hour, minute) }
    var endText: String { Self.timeText(endHour, endMinute) }

    /// "Every day", "Weekdays", "Weekends" or "Mon, Wed, Fri".
    var daysText: String {
        switch weekdays {
        case Set(1...7): return "Every day"
        case Set(2...6): return "Weekdays"
        case [1, 7]: return "Weekends"
        case []: return "Never"
        default:
            let symbols = Calendar.current.shortWeekdaySymbols
            return Routine.weekOrder.filter(weekdays.contains).map { symbols[$0 - 1] }.joined(separator: ", ")
        }
    }

    /// Weekdays in the order the user's calendar starts the week.
    static var weekOrder: [Int] {
        let first = Calendar.current.firstWeekday
        return (0..<7).map { (first - 1 + $0) % 7 + 1 }
    }

    static func timeText(_ hour: Int, _ minute: Int) -> String {
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }
}

/// The routines, stored in the App Group so the monitor and shield extensions read the same list.
enum Routines {
    private static let key = "routines"
    private static let activeKey = "activeRoutines"

    /// Each blocking routine takes one of the 20 DeviceActivity schedules and up to 7 of the 64 pending
    /// notifications, so 8 keeps both well inside the system limits.
    static let maxCount = 8

    static var all: [Routine] {
        get {
            guard let data = AppGroup.defaults.data(forKey: key),
                  let list = try? JSONDecoder().decode([Routine].self, from: data) else { return [] }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) { AppGroup.defaults.set(data, forKey: key) }
        }
    }

    static func find(_ id: UUID) -> Routine? { all.first { $0.id == id } }

    static func save(_ routine: Routine) {
        var list = all
        if let i = list.firstIndex(where: { $0.id == routine.id }) { list[i] = routine } else { list.append(routine) }
        all = list
    }

    static func remove(_ id: UUID) {
        all = all.filter { $0.id != id }
    }

    /// Routines whose block is on right now, as last applied by `RoutineBlocker.reconcile`.
    static var activeIDs: Set<UUID> {
        get { Set((AppGroup.defaults.stringArray(forKey: activeKey) ?? []).compactMap(UUID.init)) }
        set { AppGroup.defaults.set(newValue.map(\.uuidString).sorted(), forKey: activeKey) }
    }

    static var active: [Routine] {
        let ids = activeIDs
        return all.filter { ids.contains($0.id) }
    }

    /// Websites blocked by the routines that are on right now.
    static var activeSites: [String] { active.flatMap(\.sites) }
}
