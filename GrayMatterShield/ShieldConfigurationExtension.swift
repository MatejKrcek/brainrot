import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customises the full-screen shield iOS shows over a paused app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func config(name: String?) -> ShieldConfiguration {
        let snap = SharedStore.snapshot()
        let title = "\(name ?? "This app") is paused"
        let sub = "\(snap.minutes.asDuration) of scrolling today, limit \(snap.limit.asDuration). Your brain is \(snap.stage.title.lowercased()).\nOpen Brain Health to unblock for \(SharedStore.unlockMinutes) minutes."
        let icon = UIImage(systemName: "brain.head.profile",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.6),
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: sub, color: UIColor.white.withAlphaComponent(0.7)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white,
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Open Brain Health", color: .white)
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration { config(name: application.localizedDisplayName) }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { config(name: application.localizedDisplayName) }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { config(name: webDomain.domain) }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { config(name: webDomain.domain) }
}
