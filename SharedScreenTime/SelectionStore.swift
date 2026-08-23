import Foundation
import FamilyControls
import ManagedSettings

/// Persists the user's FamilyActivitySelection in the App Group so extensions can shield it.
enum SelectionStore {
    private static let key = "familySelection"

    static func load() -> FamilyActivitySelection {
        guard let data = AppGroup.defaults.data(forKey: key),
              let sel = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection(includeEntireCategory: true)
        }
        return sel
    }

    static func save(_ selection: FamilyActivitySelection) {
        if let data = try? JSONEncoder().encode(selection) {
            AppGroup.defaults.set(data, forKey: key)
        }
        SharedStore.selectionCount = selection.applicationTokens.count
            + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    static var isEmpty: Bool { SharedStore.selectionCount == 0 }
}

/// Applies / removes the shield. Safe to call from the app and from extensions.
enum ShieldController {
    static let store = ManagedSettingsStore(named: .graymatter)

    static func lock() {
        let sel = SelectionStore.load()
        store.shield.applications = sel.applicationTokens.isEmpty ? nil : sel.applicationTokens
        store.shield.applicationCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        store.shield.webDomains = sel.webDomainTokens.isEmpty ? nil : sel.webDomainTokens
        store.shield.webDomainCategories = sel.categoryTokens.isEmpty ? nil : .specific(sel.categoryTokens)
        SharedStore.isShielded = true
    }

    static func unlock() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
        store.shield.webDomainCategories = nil
        SharedStore.isShielded = false
    }

    /// Decide whether apps should be locked right now, and apply it.
    static func reconcile() {
        if SharedStore.isUnlocked || !SharedStore.lockEnabled { unlock(); return }
        SharedStore.minutesToday >= SharedStore.dailyLimit ? lock() : unlock()
    }
}
