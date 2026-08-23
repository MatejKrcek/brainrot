import SwiftUI
import FamilyControls

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var limit: Int = SharedStore.dailyLimit
    @State private var lock: Bool = SharedStore.lockEnabled
    @State private var unlockMinutes: Int = SharedStore.unlockMinutes
    @State private var showPicker = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Screen Time") {
                    HStack {
                        Text("Access")
                        Spacer()
                        if model.screenTime.isAuthorized {
                            Text("Authorised").foregroundStyle(.secondary)
                        } else {
                            Button("Allow") { Task { _ = await model.screenTime.requestAuthorization() } }
                        }
                    }
                    if model.screenTime.isAuthorized {
                        Toggle("Track selected apps", isOn: Binding(
                            get: { SharedStore.isMonitoring },
                            set: { on in on ? model.screenTime.startMonitoring() : model.screenTime.stopMonitoring(); model.refresh() }))
                        Button {
                            showPicker = true
                        } label: {
                            HStack {
                                Text("Apps")
                                Spacer()
                                Text("\(SharedStore.selectionCount) selected").foregroundStyle(.secondary)
                                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)
                    }
                    if let err = model.screenTime.lastError {
                        Text(err).font(.footnote).foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("Daily limit", selection: $limit) {
                        ForEach(LimitOptions.all, id: \.self) { Text($0.asDuration).tag($0) }
                    }
                } footer: {
                    Text("100% brain health at zero usage, 0% at the limit.")
                }

                Section {
                    Toggle("Block apps over the limit", isOn: $lock)
                    Picker("Unblock window", selection: $unlockMinutes) {
                        ForEach([15, 30, 45], id: \.self) { Text("\($0) min").tag($0) }
                    }
                } header: {
                    Text("Blocking")
                } footer: {
                    Text("When blocked, selected apps show a Gray Matter screen. You can unblock temporarily from the app; iOS requires a minimum window of 15 minutes.")
                }

                Section {
                    Text("Long-press the Home Screen, tap +, search for Gray Matter. The widget shows only your brain and updates as you use the tracked apps. Lock Screen widgets are available too.")
                        .font(.footnote).foregroundStyle(.secondary)
                } header: { Text("Widgets") }

                if !model.screenTime.isAuthorized {
                    Section {
                        Button("Add 15 minutes") { model.demoAddMinutes(15) }
                        Button("Reset today") { model.demoAddMinutes(-SharedStore.minutesToday) }
                    } header: { Text("Demo") } footer: {
                        Text("Screen Time isn't available here, so usage is simulated.")
                    }
                }

                Section {
                    Button("Reset all data", role: .destructive) { confirmReset = true }
                }

                Section {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .familyActivityPicker(isPresented: $showPicker,
                              selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection(); model.refresh() } }
        .onChange(of: limit) { _, v in SharedStore.dailyLimit = v; model.applyRules() }
        .onChange(of: lock) { _, v in SharedStore.lockEnabled = v; model.applyRules() }
        .onChange(of: unlockMinutes) { _, v in SharedStore.unlockMinutes = v }
        .confirmationDialog("Reset all data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset", role: .destructive) {
                model.screenTime.stopMonitoring()
                SharedStore.resetAll()
                model.onboarded = false
                model.refresh()
                dismiss()
            }
        } message: { Text("Usage history, limit and app selection will be removed.") }
    }
}
