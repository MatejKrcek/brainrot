import Foundation
import FamilyControls
import DeviceActivity
import ManagedSettings
import Combine

@MainActor
final class ScreenTimeManager: ObservableObject {
    @Published private(set) var status: AuthorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @Published var selection: FamilyActivitySelection = SelectionStore.load()
    @Published var lastError: String?

    private let center = DeviceActivityCenter()
    private var bag = Set<AnyCancellable>()

    var isAuthorized: Bool { status == .approved }

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
            return isAuthorized
        } catch {
            lastError = error.localizedDescription
            refreshStatus()
            return false
        }
    }

    func saveSelection() {
        SelectionStore.save(selection)
        if SharedStore.isMonitoring { startMonitoring() }
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
        do {
            try center.startMonitoring(.daily, during: schedule, events: events)
            SharedStore.isMonitoring = true
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

    /// Schedules a one-shot DeviceActivity interval ending at `until`; the monitor extension
    /// re-applies the shield in `intervalDidEnd`. (System minimum is 15 minutes.)
    func scheduleRelock(at until: Date) {
        let cal = Calendar.current
        let now = Date()
        let start = cal.dateComponents([.hour, .minute, .second], from: now)
        let end = cal.dateComponents([.hour, .minute, .second], from: until)
        let schedule = DeviceActivitySchedule(intervalStart: start, intervalEnd: end, repeats: false)
        center.stopMonitoring([.unlock])
        do { try center.startMonitoring(.unlock, during: schedule) }
        catch { lastError = "Relock schedule failed: \(error.localizedDescription)" }
    }
}
