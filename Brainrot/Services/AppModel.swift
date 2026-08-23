import SwiftUI
import WidgetKit
import Combine

enum Tab: Hashable { case brain, stats, coach, settings }

@MainActor
final class AppModel: ObservableObject {
    @Published var snap: RotSnapshot = SharedStore.snapshot()
    @Published var tab: Tab = .brain
    @Published var showChallenge = false
    @Published var onboarded: Bool = SharedStore.onboarded
    @Published var lastUnlockGranted: Date?

    let screenTime = ScreenTimeManager()
    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
        applyLaunchArguments()
    }

    /// Debug / screenshot helpers: `--tab=stats|coach|settings`, `--challenge[=math|breathe|type|hold|walk]`, `--minutes=80`.
    private func applyLaunchArguments() {
        let args = CommandLine.arguments
        func value(_ key: String) -> String? {
            args.first { $0.hasPrefix("--\(key)=") }?.split(separator: "=", maxSplits: 1).last.map(String.init)
        }
        if let m = value("minutes").flatMap(Int.init) { SharedStore.minutesToday = m; SharedStore.demoMode = true; SharedStore.onboarded = true; onboarded = true }
        if let t = value("tab") {
            switch t { case "stats": tab = .stats; case "coach": tab = .coach; case "settings": tab = .settings; default: tab = .brain }
        }
        if args.contains("--challenge") || value("challenge") != nil {
            if let k = value("challenge").flatMap(ChallengeKind.init(rawValue:)) { SharedStore.challengeKind = k }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.showChallenge = true }
        }
        if args.contains("--seed") { demoSeedHistory() }
        snap = SharedStore.snapshot()
    }

    func refresh() {
        SharedStore.rollOverIfNeeded()
        // Unlock window expired while the extension didn't fire? Re-lock ourselves.
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
        // The shield's "Open Brainrot" button leaves a marker; jump straight to the challenge.
        if AppGroup.defaults.object(forKey: "pendingUnlockRequest") != nil {
            AppGroup.defaults.removeObject(forKey: "pendingUnlockRequest")
            if onboarded { showChallenge = true }
        }
    }

    func handle(url: URL) {
        guard url.scheme == AppGroup.urlScheme else { return }
        switch url.host {
        case "challenge": tab = .brain; showChallenge = true
        case "coach": tab = .coach
        default: tab = .brain
        }
    }

    func completeOnboarding() {
        SharedStore.onboarded = true
        onboarded = true
        refresh()
    }

    /// Called when a challenge is passed.
    func grantUnlock() {
        SharedStore.challengesDone += 1
        let minutes = SharedStore.unlockMinutes
        let base = max(Date(), SharedStore.unlockUntil ?? Date())
        let until = base.addingTimeInterval(Double(minutes) * 60)
        SharedStore.unlockUntil = until
        if screenTime.isAuthorized {
            screenTime.scheduleRelock(at: until)
            ShieldController.unlock()
        }
        lastUnlockGranted = until
        refresh()
    }

    // MARK: Demo helpers (used when Screen Time isn't authorised, e.g. free dev account / simulator)

    func demoAddMinutes(_ m: Int) {
        SharedStore.minutesToday = max(0, SharedStore.minutesToday + m)
        refresh()
    }

    func demoSeedHistory() {
        var h = SharedStore.history
        let cal = Calendar.current
        let sample = [72, 41, 95, 38, 120, 55, 0]
        for (i, v) in sample.enumerated() where i > 0 {
            if let d = cal.date(byAdding: .day, value: -i, to: Date()) { h[SharedStore.key(for: d)] = v }
        }
        SharedStore.history = h
        SharedStore.streak = 2
        refresh()
    }
}
