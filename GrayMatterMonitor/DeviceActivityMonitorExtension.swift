import DeviceActivity
import ManagedSettings
import WidgetKit
import Foundation

/// Woken by the system on schedule boundaries and when usage thresholds are crossed.
/// This is the only place (besides the sandboxed report) that "sees" usage, so we turn
/// threshold events into a minute counter in the App Group.
final class DeviceActivityMonitorExtension: DeviceActivityMonitor {

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        switch activity {
        case .daily:
            SharedStore.rollOverIfNeeded()
            ShieldController.reconcile()
        case .unlock:
            ShieldController.unlock()
        case .bedtime:
            BedtimeBlocker.lock()
        default: break
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        switch activity {
        case .daily:
            // Archive today's number; tomorrow's intervalDidStart will roll the counters.
            var h = SharedStore.history
            h[SharedStore.todayKey] = SharedStore.minutesToday
            SharedStore.history = h
        case .unlock:
            SharedStore.unlockUntil = nil
            ShieldController.reconcile()
        case .bedtime:
            BedtimeBlocker.unlock()
        default: break
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)
        guard activity == .daily else { return }
        if let i = event.appIndex { SharedStore.markAppUsed(i); return }
        guard let minutes = event.tickMinutes else { return }
        SharedStore.minutesToday = max(SharedStore.minutesToday, minutes)
        if SharedStore.lockEnabled, minutes >= SharedStore.dailyLimit, !SharedStore.isUnlocked {
            ShieldController.lock()
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
    }

    /// An unblock window shorter than the 15-minute minimum interval ends here (see `scheduleRelock`).
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        guard activity == .unlock else { return }
        SharedStore.unlockUntil = nil
        ShieldController.reconcile()
        WidgetCenter.shared.reloadAllTimelines()
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventWillReachThresholdWarning(event, activity: activity)
    }
}
