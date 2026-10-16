import SwiftUI
import FamilyControls
import ManagedSettings

/// Tracked apps: whatever the user picked from the apps installed on this iPhone. Apple's Screen Time picker
/// is the only way to list them; it hands back opaque tokens that `Label(token)` renders with the real icon
/// and name, and exactly these tokens are counted and blocked.
struct TrackedAppsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var showPicker: Bool
    @State private var requesting = false
    @State private var unavailable = false

    private var selection: FamilyActivitySelection { model.screenTime.selection }
    private var authorized: Bool { model.screenTime.isAuthorized }
    private var isEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }

    var body: some View {
        Form {
            Section {
                if authorized && isEmpty {
                    Text("No apps yet").foregroundStyle(.secondary)
                }
                ForEach(Array(selection.applicationTokens), id: \.self) { token in
                    Label(token).labelStyle(.titleAndIcon)
                }
                .onDelete { offsets in remove(applications: offsets) }
                ForEach(Array(selection.categoryTokens), id: \.self) { token in
                    Label(token).labelStyle(.titleAndIcon)
                }
                .onDelete { offsets in remove(categories: offsets) }
                ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                    Label(token).labelStyle(.titleAndIcon)
                }
                .onDelete { offsets in remove(webDomains: offsets) }
                Button {
                    chooseApps()
                } label: {
                    Label(requesting ? "Opening…" : "Choose apps", systemImage: "plus.circle.fill")
                }
                .disabled(requesting)
            } header: {
                Text("Counts against your brain")
            } footer: {
                Text(authorized
                     ? "Only these apps are counted and blocked. A whole category like Social includes every app in it; to leave one out, pick apps one by one. Swipe left to remove."
                     : "Opens the list of apps on this iPhone. The first time, iOS asks for Screen Time access.")
            }
        }
        .navigationTitle("Tracked apps")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Screen Time isn't available", isPresented: $unavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This build or device can't use Apple's Screen Time picker. On an iPhone with the full app, allow Screen Time access and try again.")
        }
    }

    /// Opens the system picker, asking for Screen Time access first if needed.
    private func chooseApps() {
        if authorized { showPicker = true; return }
        requesting = true
        Task {
            let ok = await model.screenTime.requestAuthorization()
            requesting = false
            if ok { showPicker = true } else { unavailable = true }
        }
    }

    private func remove(applications offsets: IndexSet) {
        let tokens = Array(selection.applicationTokens)
        for i in offsets { model.screenTime.selection.applicationTokens.remove(tokens[i]) }
        model.screenTime.saveSelection(); model.refresh()
    }

    private func remove(categories offsets: IndexSet) {
        let tokens = Array(selection.categoryTokens)
        for i in offsets { model.screenTime.selection.categoryTokens.remove(tokens[i]) }
        model.screenTime.saveSelection(); model.refresh()
    }

    private func remove(webDomains offsets: IndexSet) {
        let tokens = Array(selection.webDomainTokens)
        for i in offsets { model.screenTime.selection.webDomainTokens.remove(tokens[i]) }
        model.screenTime.saveSelection(); model.refresh()
    }
}
