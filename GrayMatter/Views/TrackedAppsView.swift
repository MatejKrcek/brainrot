import SwiftUI

/// Toggle list of named apps, plus the user's own additions. On a device with Screen Time authorised the
/// system picker still has to confirm the same apps (Apple only exposes opaque tokens through it).
struct TrackedAppsView: View {
    @EnvironmentObject var model: AppModel
    @Binding var ids: Set<String>
    @Binding var showPicker: Bool
    @State private var customNames: [String] = SharedStore.customAppNames
    @State private var newName = ""
    @FocusState private var nameFocused: Bool

    private var customApps: [TrackedApp] { customNames.map(TrackedApp.custom) }

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
                ForEach(customApps) { app in toggle(app) }
                    .onDelete(perform: deleteCustom)
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(.green)
                    TextField("Add another app", text: $newName)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .onSubmit(addCustom)
                    if !newName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Button("Add", action: addCustom).buttonStyle(.borderless)
                    }
                }
            } header: {
                Text("Other apps")
            } footer: {
                Text(model.screenTime.isAuthorized
                     ? "Type a name, or pick apps and whole categories straight from Screen Time below."
                     : "Type a name. Swipe left to remove an app you added.")
            }

            if model.screenTime.isAuthorized {
                Section {
                    Button {
                        showPicker = true
                    } label: {
                        HStack {
                            Label("Add from Screen Time", systemImage: "hourglass")
                            Spacer()
                            Text("\(SharedStore.selectionCount) selected").foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .tint(.primary)
                } footer: {
                    Text("iOS only lets Brain Health count apps you pick in Apple's Screen Time picker. Choose the apps above there once; categories like Social work too. Counting starts as soon as you pick them.")
                }
            }

            Section {
                Button("Reset to defaults") { ids = TrackedApp.defaultIDs }
                    .disabled(ids == TrackedApp.defaultIDs)
            }
        }
        .navigationTitle("Tracked apps")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: customNames) { _, v in SharedStore.customAppNames = v }
    }

    private func toggle(_ app: TrackedApp) -> some View {
        Toggle(isOn: Binding(
            get: { ids.contains(app.id) },
            set: { on in if on { ids.insert(app.id) } else { ids.remove(app.id) } })) {
            Label(app.name, systemImage: app.symbol)
        }
    }

    private func addCustom() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let app = TrackedApp.custom(name)
        guard !TrackedApp.all.contains(where: { $0.id == app.id }) else { newName = ""; return }
        customNames.append(name)
        ids.insert(app.id)
        newName = ""
        nameFocused = true
    }

    private func deleteCustom(at offsets: IndexSet) {
        for i in offsets { ids.remove(customApps[i].id) }
        customNames.remove(atOffsets: offsets)
    }
}
