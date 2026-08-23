import ManagedSettings
import ManagedSettingsUI
import UIKit

/// Customises the full-screen shield that iOS shows over a locked app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func config(name: String?) -> ShieldConfiguration {
        let snap = SharedStore.snapshot()
        let stage = snap.stage
        let title = "\(stage.emoji) Brain \(snap.rotPercent)% rotten"
        let sub = "\(name ?? "This app") is locked. \(snap.minutes.asDuration) scrolled today.\nOpen Brainrot and earn \(SharedStore.unlockMinutes) min with a challenge."
        let icon = UIImage(systemName: "brain.head.profile",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 44, weight: .bold))?
            .withTintColor(UIColor(red: 0.78, green: 1.0, blue: 0.24, alpha: 1), renderingMode: .alwaysOriginal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 0.9),
            icon: icon,
            title: ShieldConfiguration.Label(text: title, color: .white),
            subtitle: ShieldConfiguration.Label(text: sub, color: UIColor.white.withAlphaComponent(0.7)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "Fine, I'll stop", color: .black),
            primaryButtonBackgroundColor: UIColor(red: 0.78, green: 1.0, blue: 0.24, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Open Brainrot", color: UIColor(red: 0.78, green: 1.0, blue: 0.24, alpha: 1))
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        config(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        config(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        config(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        config(name: webDomain.domain)
    }
}
