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
    @State private var trackedIDs: Set<String> = SharedStore.trackedAppIDs
    @State private var path = NavigationPath()

    private enum Route: Hashable { case trackedApps }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    NavigationLink(value: Route.trackedApps) {
                        HStack {
                            Label("Tracked apps", systemImage: "square.grid.2x2")
                            Spacer()
                            Text(TrackedApp.summary(trackedIDs, extra: SharedStore.selectionCount)).foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Apps")
                } footer: {
                    Text(model.screenTime.isAuthorized
                         ? "Confirm the same apps in Apple's Screen Time picker inside Tracked apps."
                         : "Screen Time isn't authorised here, so usage of these apps is simulated.")
                }

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
                    Text("When blocked, selected apps show a Brain Health screen. You can unblock temporarily from the app; iOS requires a minimum window of 15 minutes.")
                }

                Section {
                    HStack {
                        Text("Shared data")
                        Spacer()
                        if AppGroup.isAvailable {
                            Label("Working", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                        } else {
                            Label("Unavailable", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        }
                    }
                    .font(.subheadline)
                    if !AppGroup.isAvailable {
                        Text("This build can't use the App Group, so the widget can't read the app's data. In Xcode, add the App Groups capability (group.cz.krcek.brainhealth) to the app and widget targets under Signing & Capabilities.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                    Button("Refresh widgets now") { model.reloadWidgets(force: true) }
                    Text("Long-press the Home Screen, tap +, search for Brain Health. Screen time shows the brain with today's minutes and what's left; Brain is the brain alone. Both update as you use the tracked apps, and both come as Lock Screen widgets too.")
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
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .trackedApps: TrackedAppsView(ids: $trackedIDs, showPicker: $showPicker).environmentObject(model)
                }
            }
            .onAppear {
                if model.openTrackedApps { model.openTrackedApps = false; path.append(Route.trackedApps) }
            }
        }
        .familyActivityPicker(isPresented: $showPicker,
                              selection: Binding(get: { model.screenTime.selection }, set: { model.screenTime.selection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { model.screenTime.saveSelection(); model.refresh() } }
        .onChange(of: limit) { _, v in SharedStore.dailyLimit = v; model.applyRules(); model.reloadWidgets(force: true) }
        .onChange(of: lock) { _, v in SharedStore.lockEnabled = v; model.applyRules() }
        .onChange(of: unlockMinutes) { _, v in SharedStore.unlockMinutes = v }
        .onChange(of: trackedIDs) { _, v in SharedStore.trackedAppIDs = v; model.refresh() }
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
