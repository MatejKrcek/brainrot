import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var selection: FamilyActivitySelection = SelectionStore.load()
    /// Apps blocked at night, picked separately from `selection`.
    @Published var bedtimeSelection: FamilyActivitySelection = Bedtime.loadSelection()
    @Published var lastError: String?

    private let center = DeviceActivityCenter()
    private var bag = Set<AnyCancellable>()

    var isAuthorized: Bool { status == .approved }
    /// Bump when the daily schedule's events change, so installs already monitoring re-register.
    private static let schema = 2

    init() {
        AuthorizationCenter.shared.$authorizationStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.status = $0 }
            .store(in: &bag)
    }

    func refreshStatus() { status = AuthorizationCenter.shared.authorizationStatus }

    func requestAuthorization() async -> Bool {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            refreshStatus()
            if isAuthorized && !SelectionStore.isEmpty { startMonitoring() }
            if isAuthorized { scheduleBedtime() }
            return isAuthorized
        } catch {
            lastError = error.localizedDescription
            refreshStatus()
            return false
        }
    }

    func saveSelection() {
        SelectionStore.save(selection)
        // Indices into the picked apps change with the selection, so the per-app marks start over.
        SharedStore.usedAppsToday = []
        // Anything picked in Screen Time should be counted straight away.
        if isAuthorized && !SelectionStore.isEmpty { startMonitoring() } else if SelectionStore.isEmpty { stopMonitoring() }
    }

    /// Called on every foreground. Screen Time silently drops schedules (reinstall, restore, iOS update),
    /// so re-register when we think we're monitoring but the system has no active schedule.
    func ensureMonitoring() {
        guard isAuthorized else { return }
        let active = center.activities
        if Bedtime.enabled, !active.contains(.bedtime) {
            scheduleBedtime()
        } else {
            // Backstop for a missed intervalDidStart / intervalDidEnd.
            BedtimeBlocker.reconcile()
        }
        if SharedStore.isMonitoring, !active.contains(.daily) || SharedStore.monitorSchema != Self.schema {
            startMonitoring()
        } else if !SharedStore.isMonitoring, SharedStore.onboarded, !SelectionStore.isEmpty, !SharedStore.demoMode {
            startMonitoring()
        }
    }

    /// (Re)starts the all-day usage monitor with minute-resolution thresholds.
    func startMonitoring() {
        guard isAuthorized else { return }
        center.stopMonitoring([.daily])
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true)
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [:]
        for m in Ticks.all {
            events[.tick(m)] = DeviceActivityEvent(
                applications: selection.applicationTokens,
                categories: selection.categoryTokens,
                webDomains: selection.webDomainTokens,
                threshold: DateComponents(hour: m / 60, minute: m % 60))
        }
        // One event per picked app so the app knows how many apps were used today (see `SharedStore.usedAppsToday`).
        for (i, token) in SelectionStore.orderedApplications(selection).enumerated() {
            events[.app(i)] = DeviceActivityEvent(applications: [token], threshold: DateComponents(minute: 1))
        }
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            SharedStore.isMonitoring = true
            SharedStore.monitorSchema = Self.schema
            ShieldController.reconcile()
            lastError = nil
        } catch {
            lastError = "Monitoring failed: \(error.localizedDescription)"
            SharedStore.isMonitoring = false
        }
    }

    func stopMonitoring() {
        center.stopMonitoring([.daily, .unlock])
        ShieldController.unlock()
        SharedStore.isMonitoring = false
        SharedStore.unlockUntil = nil
    }

    func saveBedtimeSelection() {
        Bedtime.saveSelection(bedtimeSelection)
        scheduleBedtime()
    }

    /// (Re)registers the nightly schedule from `Bedtime`, or removes it when bedtime is off. The interval
    /// crosses midnight (22:00 to 8:00); the monitor extension shields at its start and lifts it at its end.
    func scheduleBedtime() {
        center.stopMonitoring([.bedtime])
        defer { BedtimeBlocker.reconcile() }
        guard isAuthorized, Bedtime.enabled, Bedtime.selectionCount > 0,
              Bedtime.length(start: Bedtime.startMinute, end: Bedtime.endMinute) >= Bedtime.minimumLength else { return }
        let schedule = DeviceActivitySchedule(
            intervalStart: Bedtime.components(Bedtime.startMinute),
            intervalEnd: Bedtime.components(Bedtime.endMinute),
            repeats: true)
        do {
            try center.startMonitoring(.bedtime, during: schedule)
            lastError = nil
        } catch {
            lastError = "Bedtime schedule failed: \(error.localizedDescription)"
        }
    }

    /// Schedules a one-shot DeviceActivity interval so the monitor extension re-applies the shield at `until`.
    /// The system won't take an interval shorter than 15 minutes, so a shorter window gets a 15-minute interval
    /// with a warning timed to fire at `until`; the extension relocks in `intervalWillEndWarning` and
    /// `intervalDidEnd` is the backstop.
    func scheduleRelock(at until: Date) {
        let cal = Calendar.current
        let now = Date()
        let minimum: TimeInterval = 15 * 60
        let length = max(minimum, until.timeIntervalSince(now))
        let end = now.addingTimeInterval(length)
        let early = end.timeIntervalSince(until)
        let warning = early >= 60 ? DateComponents(minute: Int(early / 60), second: Int(early) % 60) : nil
        let schedule = DeviceActivitySchedule(
            intervalStart: cal.dateComponents([.hour, .minute, .second], from: now),
            intervalEnd: cal.dateComponents([.hour, .minute, .second], from: end),
            repeats: false,
            warningTime: warning)
        center.stopMonitoring([.unlock])
        do { try center.startMonitoring(.unlock, during: schedule) }
        catch { lastError = "Relock schedule failed: \(error.localizedDescription)" }
    }
}
