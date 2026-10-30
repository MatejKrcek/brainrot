import SwiftUI
import FamilyControls
import ManagedSettings

/// Bedtime: apps picked separately from the tracked ones, fully blocked every night (default 22:00 to 8:00).
struct BedtimeView: View {
    @EnvironmentObject var model: AppModel
    @State private var enabled = Bedtime.enabled
    @State private var start = BedtimeView.date(Bedtime.startMinute)
    @State private var end = BedtimeView.date(Bedtime.endMinute)
    @State private var showPicker = false
    @State private var requesting = false
    @State private var unavailable = false

    private var selection: FamilyActivitySelection { model.screenTime.bedtimeSelection }
    private var authorized: Bool { model.screenTime.isAuthorized }
    private var isEmpty: Bool {
        selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty && selection.webDomainTokens.isEmpty
    }
    private var tooShort: Bool {
        Bedtime.length(start: Self.minute(start), end: Self.minute(end)) < Bedtime.minimumLength
    }

    var body: some View {
        Form {
            Section {
                Toggle("Block apps at night", isOn: $enabled)
                DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
                DatePicker("Until", selection: $end, displayedComponents: .hourAndMinute)
                if tooShort {
                    Text("Bedtime has to last at least \(Bedtime.minimumLength) minutes.").font(.footnote).foregroundStyle(.red)
                } else if enabled && isEmpty {
                    Text("Pick the apps to block below.").font(.footnote).foregroundStyle(.orange)
                } else if enabled && Bedtime.isActive() {
                    Label("Blocked right now", systemImage: "moon.zzz.fill").font(.footnote).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Every night from \(Self.label(start)) until \(Self.label(end)) these apps are fully blocked. No unblock button, no extra minutes. They open again in the morning.")
            }

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
                Text("Blocked at night")
            } footer: {
                Text("Separate from your tracked apps: pick anything installed on this iPhone. Swipe left to remove. Changes made during bedtime apply straight away.")
            }
        }
        .navigationTitle("Bedtime")
        .navigationBarTitleDisplayMode(.inline)
        .familyActivityPicker(headerText: "Pick the apps to block at night",
                              isPresented: $showPicker,
                              selection: Binding(get: { model.screenTime.bedtimeSelection },
                                                 set: { model.screenTime.bedtimeSelection = $0 }))
        .onChange(of: showPicker) { _, shown in if !shown { save() } }
        .onChange(of: enabled) { _, v in Bedtime.enabled = v; reschedule() }
        .onChange(of: start) { _, v in Bedtime.startMinute = Self.minute(v); reschedule() }
        .onChange(of: end) { _, v in Bedtime.endMinute = Self.minute(v); reschedule() }
        .alert("Screen Time isn't available", isPresented: $unavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This build or device can't use Apple's Screen Time picker. On an iPhone with the full app, allow Screen Time access and try again.")
        }
    }

    private func chooseApps() {
        if authorized { showPicker = true; return }
        requesting = true
        Task {
            let ok = await model.screenTime.requestAuthorization()
            requesting = false
            if ok { showPicker = true } else { unavailable = true }
        }
    }

    private func save() {
        model.screenTime.saveBedtimeSelection()
        model.refresh()
    }

    private func reschedule() {
        model.screenTime.scheduleBedtime()
        model.refresh()
    }

    private func remove(applications offsets: IndexSet) {
        let tokens = Array(selection.applicationTokens)
        for i in offsets { model.screenTime.bedtimeSelection.applicationTokens.remove(tokens[i]) }
        save()
    }

    private func remove(categories offsets: IndexSet) {
        let tokens = Array(selection.categoryTokens)
        for i in offsets { model.screenTime.bedtimeSelection.categoryTokens.remove(tokens[i]) }
        save()
    }

    private func remove(webDomains offsets: IndexSet) {
        let tokens = Array(selection.webDomainTokens)
        for i in offsets { model.screenTime.bedtimeSelection.webDomainTokens.remove(tokens[i]) }
        save()
    }

    private static func date(_ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
    }

    private static func minute(_ date: Date) -> Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    private static func label(_ date: Date) -> String { Bedtime.label(minute(date)) }
}
