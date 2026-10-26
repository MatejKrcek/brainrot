import Foundation
import DeviceActivity
import FamilyControls
import ManagedSettings
import UserNotifications

extension DeviceActivityName {
    static let routinePrefix = "graymatter.routine."
    static func routine(_ id: UUID) -> DeviceActivityName { .init(routinePrefix + id.uuidString) }
    var routineID: UUID? {
        guard rawValue.hasPrefix(Self.routinePrefix) else { return nil }
        return UUID(uuidString: String(rawValue.dropFirst(Self.routinePrefix.count)))
    }
}

/// The apps a routine blocks, picked with Apple's Screen Time picker. Kept apart from `Routine`
/// because the widget doesn't link FamilyControls.
enum RoutineSelections {
    private static func key(_ id: UUID) -> String { "routineSelection." + id.uuidString }

    static func load(_ id: UUID) -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: key(id)),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return sel
    }

    static func save(_ selection: FamilyActivitySelection, for id: UUID) {
        if let data = try? JSONEncoder().encode(selection) { AppGroup.defaults.set(data, forKey: key(id)) }
    }

    static func remove(_ id: UUID) { AppGroup.defaults.removeObject(forKey: key(id)) }
}

/// Shields a routine's apps while its window is on. Each routine has its own store, so ending one never
/// lifts another routine's block or the daily-limit shield, and the unblock window doesn't touch it.
enum RoutineBlocker {
    static func store(_ id: UUID) -> ManagedSettingsStore {
        ManagedSettingsStore(named: .init(DeviceActivityName.routinePrefix + id.uuidString))
    }

    /// Applies every routine's block for `now`. `forcing` pins one routine on or off, for the monitor
    /// extension's interval callbacks, which can arrive a moment before the minute they belong to.
    static func reconcile(now: Date = Date(), forcing: (id: UUID, on: Bool)? = nil) {
        var active = Set(Routines.all.filter { $0.isBlocking(at: now) }.map(\.id))
        if let forcing {
            if forcing.on { active.insert(forcing.id) } else { active.remove(forcing.id) }
        }
        for routine in Routines.all {
            let s = store(routine.id)
            guard active.contains(routine.id) else { s.clearAllSettings(); continue }
            let sel = RoutineSelections.load(routine.id)
            s.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
            s.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
            s.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
            s.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        }
        Routines.activeIDs = active
        WebsiteBlocker.apply()
    }

    /// Monitor extension: a routine's window opened. Days the routine is off still get the callback, and so
    /// does a schedule re-registered mid-window, so ask the routine; a minute ahead covers an early callback.
    static func intervalStarted(_ id: UUID, now: Date = Date()) {
        reconcile(now: now, forcing: (id, Routines.find(id)?.isBlocking(at: now.addingTimeInterval(60)) == true))
    }

    static func intervalEnded(_ id: UUID) {
        reconcile(forcing: (id, false))
    }
}

/// Registers one repeating DeviceActivity schedule per blocking routine and drops the ones that are gone.
enum RoutineScheduler {
    private static let center = DeviceActivityCenter()

    static func sync() {
        let routines = Routines.all
        let wanted = Dictionary(uniqueKeysWithValues: routines
            .filter { $0.enabled && $0.blocks && $0.isBlockValid }
            .map { (DeviceActivityName.routine($0.id), $0) })

        let stale = center.activities.filter { $0.routineID != nil && wanted[$0] == nil }
        if !stale.isEmpty { center.stopMonitoring(stale) }
        for activity in stale {
            if let id = activity.routineID, Routines.find(id) == nil { RoutineBlocker.store(id).clearAllSettings() }
        }

        for (name, routine) in wanted {
            let schedule = DeviceActivitySchedule(
                intervalStart: DateComponents(hour: routine.hour, minute: routine.minute),
                intervalEnd: DateComponents(hour: routine.endHour, minute: routine.endMinute),
                repeats: true)
            // Re-register only when the times changed, so an open window isn't restarted on every foreground.
            if center.activities.contains(name), let current = center.schedule(for: name),
               current.intervalStart.hour == routine.hour, current.intervalStart.minute == routine.minute,
               current.intervalEnd.hour == routine.endHour, current.intervalEnd.minute == routine.endMinute {
                continue
            }
            center.stopMonitoring([name])
            try? center.startMonitoring(name, during: schedule)
        }
        RoutineBlocker.reconcile()
    }

    /// Stops every routine schedule and lifts their blocks (Reset all data).
    static func stopAll() {
        let names = center.activities.filter { $0.routineID != nil }
        center.stopMonitoring(names)
        for name in names { if let id = name.routineID { RoutineBlocker.store(id).clearAllSettings() } }
        for routine in Routines.all { RoutineBlocker.store(routine.id).clearAllSettings() }
        Routines.activeIDs = []
    }
}

/// Local notifications for the routines: one repeating request per weekday, or one daily request.
enum RoutineNotifications {
    private static let prefix = "routine."

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            center.removePendingNotificationRequests(withIdentifiers: pending.map(\.identifier).filter { $0.hasPrefix(prefix) })
            for routine in Routines.all where routine.enabled && !routine.weekdays.isEmpty {
                let content = UNMutableNotificationContent()
                content.title = routine.title
                content.body = routine.blocks && routine.isBlockValid
                    ? "\(routine.message)\nApps are blocked until \(routine.endText)."
                    : routine.message
                content.sound = .default
                let days: [Int?] = routine.weekdays.count == 7 ? [nil] : routine.weekdays.sorted()
                for day in days {
                    var when = DateComponents(hour: routine.hour, minute: routine.minute)
                    when.weekday = day
                    let id = prefix + routine.id.uuidString + "." + (day.map(String.init) ?? "daily")
                    let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
                    center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
                }
            }
        }
    }
}
