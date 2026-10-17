import SwiftUI
import WidgetKit
import Combine
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var snap: RotSnapshot = SharedStore.snapshot()
    @Published var onboarded: Bool = SharedStore.onboarded
    @Published var showSettings = false
    /// Set by `--apps`; SettingsView pushes Tracked apps on first appearance.
    @Published var openTrackedApps = false
    /// `--store`: hide the demo card and show "Tracking" for App Store screenshots.
    @Published var storeMode = false
    /// The "instead" quote on Home. Re-rolled every time the app comes to the foreground.
    @Published var alternative: Alternative?
    /// Home's tap-to-unblock challenge. Also raised when the user arrives from the shield's Unblock button.
    @Published var showUnblockChallenge = false

    let screenTime = ScreenTimeManager()
    private var timer: AnyCancellable?
    /// Last snapshot pushed to WidgetKit. Reloads are budgeted per day, so only reload on change.
    private var lastWidgetSnap: RotSnapshot?

    init() {
        timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        applyLaunchArguments()
    }

    /// Debug / screenshot helpers: `--minutes=80`, `--blocked`, `--settings`, `--apps`, `--store`, `--step=N` (onboarding step).
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        if let arg = args.first(where: { $0.hasPrefix("--minutes=") }), let m = Int(arg.dropFirst("--minutes=".count)) {
            SharedStore.minutesToday = m; SharedStore.demoMode = true; SharedStore.onboarded = true; onboarded = true
        }
        if args.contains("--blocked") { SharedStore.lockEnabled = true; SharedStore.isShielded = true }
        storeMode = args.contains("--store")
        if args.contains("--settings") || args.contains("--apps") {
            openTrackedApps = args.contains("--apps")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showSettings = true }
        }
        snap = SharedStore.snapshot()
        rollAlternative()
    }

    /// Picks a different "you could have…" line than last time.
    func rollAlternative() {
        alternative = Alternative.random(for: SharedStore.minutesToday, except: alternative?.id)
    }

    func refresh() {
        SharedStore.rollOverIfNeeded()
        if let until = SharedStore.unlockUntil, until <= Date() {
            SharedStore.unlockUntil = nil
            if screenTime.isAuthorized { ShieldController.reconcile() }
        }
        snap = SharedStore.snapshot()
        reloadWidgets()
    }

    /// Pushes the current state to the widgets. `force` skips the change check (settings edits, resets).
    func reloadWidgets(force: Bool = false) {
        let current = SharedStore.snapshot()
        guard force || current != lastWidgetSnap else { return }
        lastWidgetSnap = current
        WidgetCenter.shared.reloadAllTimelines()
    }

    func becameActive() {
        screenTime.refreshStatus()
        screenTime.ensureMonitoring()
        refresh()
        rollAlternative()
        reloadWidgets(force: true)
        requestNotificationsIfNeeded()
        consumeUnblockRequest()
    }

    /// Before iOS 26.5 the shield's Unblock button can only post a notification, so blocking needs permission to show one.
    func requestNotificationsIfNeeded() {
        if #available(iOS 26.5, *) { return }
        guard SharedStore.lockEnabled, screenTime.isAuthorized else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
    }

    /// Offers the unblock if the user just tapped Unblock on the shield (see `UnblockRequest`).
    private func consumeUnblockRequest() {
        let d = AppGroup.defaults
        let requested = d.object(forKey: UnblockRequest.key) as? Date
        d.removeObject(forKey: UnblockRequest.key)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [UnblockRequest.notificationID])
        guard let requested, Date().timeIntervalSince(requested) < UnblockRequest.ttl,
              snap.isShielded, !snap.isUnlocked else { return }
        showSettings = false
        // Give Home a moment to be on screen after a cold launch from the notification.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.showUnblockChallenge = true }
    }

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        if url.host == "settings" { showSettings = true }
    }

    func completeOnboarding() {
        SharedStore.onboarded = true
        onboarded = true
        requestNotificationsIfNeeded()
        refresh()
    }

    /// Temporarily lifts the block.
    func unblock() {
        let minutes = SharedStore.unlockMinutes
        let until = Date().addingTimeInterval(Double(minutes) * 60)
        SharedStore.unlockUntil = until
        if screenTime.isAuthorized {
            screenTime.scheduleRelock(at: until)
            ShieldController.unlock()
        }
        refresh()
    }

    func applyRules() {
        if screenTime.isAuthorized && SharedStore.isMonitoring { ShieldController.reconcile() }
        requestNotificationsIfNeeded()
        refresh()
    }

    // Demo helpers (no Screen Time authorisation: simulator / free developer team)
    func demoAddMinutes(_ m: Int) {
        SharedStore.minutesToday = max(0, SharedStore.minutesToday + m)
        refresh()
    }
}
