import ManagedSettings
import FamilyControls
import UserNotifications
import Foundation

/// Handles the buttons on the shield. The secondary button opens Brain Health, which offers the unblock
/// (see `UnblockRequest`). Before iOS 26.5 a shield can't open an app, so it closes the shielded app and
/// posts a notification that opens Brain Health when tapped.
final class ShieldActionExtension: ShieldActionDelegate {

    private func handle(_ action: ShieldAction, bedtime: Bool, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        // The bedtime shield has no Unblock button; if a stale daily-limit shield still shows one, it does nothing.
        if bedtime { completionHandler(.close); return }
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            AppGroup.defaults.set(Date(), forKey: UnblockRequest.key)
            if #available(iOS 26.5, *) {
                completionHandler(.openParentalControlsApp)
            } else {
                postUnblockNotification { completionHandler(.close) }
            }
        @unknown default:
            completionHandler(.close)
        }
    }

    /// Delivered immediately; the same identifier replaces an earlier, untapped one.
    private func postUnblockNotification(then done: @escaping () -> Void) {
        let content = UNMutableNotificationContent()
        content.title = "Unblock for \(SharedStore.unlockMinutes) minutes?"
        content.body = "Tap to open Brain Health."
        let request = UNNotificationRequest(identifier: UnblockRequest.notificationID, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in done() }
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, bedtime: inBedtime { $0.applicationTokens.contains(application) }, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, bedtime: inBedtime { $0.webDomainTokens.contains(webDomain) }, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, bedtime: inBedtime { $0.categoryTokens.contains(category) }, completionHandler: completionHandler)
    }

    /// True during the bedtime window when the bedtime selection contains the shielded item.
    private func inBedtime(_ contains: (FamilyActivitySelection) -> Bool) -> Bool {
        guard Bedtime.isActive(),
              let data = AppGroup.defaults.data(forKey: Bedtime.selectionKey),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return false }
        return contains(sel)
    }
}
