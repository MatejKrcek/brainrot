import ManagedSettings
import Foundation

/// Handles the buttons on the shield. iOS does not let a shield open another app,
/// so the secondary button can only close the shielded app; the user then opens Gray Matter.
final class ShieldActionExtension: ShieldActionDelegate {

    private func handle(_ action: ShieldAction, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)
        case .secondaryButtonPressed:
            // Mark that the user asked to unlock; the app surfaces the challenge on launch.
            AppGroup.defaults.set(Date(), forKey: "pendingUnlockRequest")
            completionHandler(.close)
        @unknown default:
            completionHandler(.close)
        }
    }

    override func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        handle(action, completionHandler: completionHandler)
    }
}
