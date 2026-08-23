import SwiftUI
import WidgetKit
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published var snap: RotSnapshot = SharedStore.snapshot()
    @Published var onboarded: Bool = SharedStore.onboarded
    @Published var showSettings = false

    let screenTime = ScreenTimeManager()
    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        applyLaunchArguments()
    }

    /// Debug / screenshot helpers: `--minutes=80`, `--settings`.
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        if let arg = args.first(where: { $0.hasPrefix("--minutes=") }), let m = Int(arg.dropFirst("--minutes=".count)) {
            SharedStore.minutesToday = m; SharedStore.demoMode = true; SharedStore.onboarded = true; onboarded = true
        }
        if args.contains("--settings") { DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.showSettings = true } }
        snap = SharedStore.snapshot()
    }

    func refresh() {
        SharedStore.rollOverIfNeeded()
        if let until = SharedStore.unlockUntil, until <= Date() {
            SharedStore.unlockUntil = nil
            if screenTime.isAuthorized { ShieldController.reconcile() }
        }
        snap = SharedStore.snapshot()
        WidgetCenter.shared.reloadAllTimelines()
    }

    func becameActive() {
        screenTime.refreshStatus()
        refresh()
        AppGroup.defaults.removeObject(forKey: "pendingUnlockRequest")
    }

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        if url.host == "settings" { showSettings = true }
    }

    func completeOnboarding() {
        SharedStore.onboarded = true
        onboarded = true
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
        refresh()
    }

    // Demo helpers (no Screen Time authorisation: simulator / free developer team)
    func demoAddMinutes(_ m: Int) {
        SharedStore.minutesToday = max(0, SharedStore.minutesToday + m)
        refresh()
    }
}
