import ManagedSettings
import ManagedSettingsUI
import FamilyControls
import UIKit

/// Customises the full-screen shield iOS shows over a paused app.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    private func config(name: String?) -> ShieldConfiguration {
        let snap = SharedStore.snapshot()
        let title = "\(name ?? "This app") is paused"
        var sub = "\(snap.minutes.asDuration) of scrolling today, limit \(snap.limit.asDuration). Your brain is \(snap.stage.title.lowercased())."
        if #unavailable(iOS 26.5) {
            // The Unblock button can't open Brain Health here; it posts a notification instead.
            sub += "\nNeed it? Tap Unblock, then the Brain Health notification."
        }
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
            secondaryButtonLabel: ShieldConfiguration.Label(text: "Unblock for \(SharedStore.unlockMinutes) min", color: .white)
        )
    }

    /// Shown over a bedtime app during the night: only OK, no way to unblock until the morning.
    private func bedtimeConfig(name: String?) -> ShieldConfiguration {
        let until = Bedtime.label(Bedtime.endMinute)
        let icon = UIImage(systemName: "moon.zzz.fill",
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: 40, weight: .medium))?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
        return ShieldConfiguration(
            backgroundBlurStyle: .systemMaterialDark,
            backgroundColor: UIColor.black.withAlphaComponent(0.6),
            icon: icon,
            title: ShieldConfiguration.Label(text: "\(name ?? "This app") is asleep", color: .white),
            subtitle: ShieldConfiguration.Label(text: "Bedtime. Blocked until \(until), no exceptions. Put the phone down.",
                                                color: UIColor.white.withAlphaComponent(0.7)),
            primaryButtonLabel: ShieldConfiguration.Label(text: "OK", color: .black),
            primaryButtonBackgroundColor: .white
        )
    }

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        BedtimeShield.covers(application: application.token)
            ? bedtimeConfig(name: application.localizedDisplayName) : config(name: application.localizedDisplayName)
    }
    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        BedtimeShield.covers(application: application.token, category: category.token)
            ? bedtimeConfig(name: application.localizedDisplayName) : config(name: application.localizedDisplayName)
    }
    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        BedtimeShield.covers(webDomain: webDomain.token) ? bedtimeConfig(name: webDomain.domain) : config(name: webDomain.domain)
    }
    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        BedtimeShield.covers(webDomain: webDomain.token, category: category.token)
            ? bedtimeConfig(name: webDomain.domain) : config(name: webDomain.domain)
    }
}

/// Whether a shielded item is blocked by bedtime right now (the daily-limit shield offers an unblock, bedtime doesn't).
/// An app in both lists counts as bedtime: unblocking the daily limit wouldn't open it anyway.
enum BedtimeShield {
    static func covers(application: ApplicationToken? = nil, webDomain: WebDomainToken? = nil,
                       category: ActivityCategoryToken? = nil) -> Bool {
        guard Bedtime.isActive(),
              let data = AppGroup.defaults.data(forKey: Bedtime.selectionKey),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else { return false }
        if let application, sel.applicationTokens.contains(application) { return true }
        if let webDomain, sel.webDomainTokens.contains(webDomain) { return true }
        if let category, sel.categoryTokens.contains(category) { return true }
        return false
    }
}
