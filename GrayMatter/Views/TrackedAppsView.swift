import SwiftUI
import FamilyControls
import ManagedSettings

/// Tracked apps: the built-in list with toggles plus whatever the user picked from the installed apps
/// (Apple's Screen Time picker is the only way to list installed apps; it hands back opaque tokens
/// that `Label(token)` renders with the real icon and name).
struct TrackedAppsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var ids: Set<String>
    @Binding var showPicker: Bool
    @State private var requesting = false
    @State private var unavailable = false

    private var selection: FamilyActivitySelection { model.screenTime.selection }

    var body: some View {
        Form {
            Section {
                ForEach(TrackedApp.builtIn) { app in toggle(app) }
            } header: {
                Text("Counts against your brain")
            } footer: {
                Text("Time spent in these apps drains brain health. TikTok, Instagram, X, LinkedIn and Threads are on by default.")
            }

            Section {
                ForEach(Array(selection.applicationTokens), id: \.self) { token in
                    Label(token).labelStyle(.titleAndIcon)
                }
                .onDelete { offsets in remove(applications: offsets) }
                ForEach(Array(selection.categoryTokens), id: \.self) { token in
                    Label(token).labelStyle(.titleAndIcon)
                }
                .onDelete { offsets in remove(categories: offsets) }
                Button {
                    addFromDevice()
                } label: {
                    HStack {
                        Label(requesting ? "Opening…" : "Add another app", systemImage: "plus.circle.fill")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .disabled(requesting)
            } header: {
                Text("Other apps on this iPhone")
            } footer: {
                Text(model.screenTime.isAuthorized
                     ? "Pick any installed app or a whole category like Social. Swipe left to remove one."
                     : "Opens Apple's app picker. The first time, iOS asks for Screen Time access.")
            }

            Section {
                Button("Reset to defaults") { ids = TrackedApp.defaultIDs }
                    .disabled(ids == TrackedApp.defaultIDs)
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

    private func toggle(_ app: TrackedApp) -> some View {
        Toggle(isOn: Binding(
            get: { ids.contains(app.id) },
            set: { on in if on { ids.insert(app.id) } else { ids.remove(app.id) } })) {
            Label(app.name, systemImage: app.symbol)
        }
    }

    /// Opens the system picker, asking for Screen Time access first if needed.
    private func addFromDevice() {
        if model.screenTime.isAuthorized { showPicker = true; return }
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
}
