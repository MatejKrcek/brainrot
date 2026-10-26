import SwiftUI
import FamilyControls
import UserNotifications

/// Reminders at a set time ("Time to read" at 23:00) that can block apps and websites until morning.
struct RoutinesView: View {
    @EnvironmentObject var model: AppModel
    @State private var routines: [Routine] = Routines.all
    @State private var editing: Routine?
    @State private var notificationsOff = false

    var body: some View {
        Form {
            if notificationsOff {
                Section {
                    Button("Turn on notifications") {
                        if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
                    }
                } footer: {
                    Text("Notifications are off for Brain Health, so routines can't remind you.")
                }
            }

            Section {
                if routines.isEmpty {
                    Text("No routines yet").foregroundStyle(.secondary)
                }
                ForEach(routines) { routine in
                    Button { editing = routine } label: { RoutineRow(routine: routine) }
                        .foregroundStyle(.primary)
                }
                .onDelete { offsets in
                    for i in offsets { delete(routines[i].id) }
                }
                if routines.count < Routines.maxCount {
                    Button { editing = Routine() } label: { Label("Add routine", systemImage: "plus.circle.fill") }
                }
            } footer: {
                Text("Swipe left to remove. Up to \(Routines.maxCount) routines.")
            }
        }
        .navigationTitle("Routines")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { routine in
            RoutineEditor(routine: routine, isNew: Routines.find(routine.id) == nil,
                          onSave: save, onDelete: { delete(routine.id) })
                .environmentObject(model)
        }
        .task { await checkNotifications() }
    }

    private func save(_ routine: Routine) {
        Routines.save(routine)
        sync()
        Task {
            _ = await RoutineNotifications.requestPermission()
            await checkNotifications()
        }
    }

    private func delete(_ id: UUID) {
        Routines.remove(id)
        RoutineSelections.remove(id)
        sync()
    }

    private func sync() {
        routines = Routines.all
        model.syncRoutines()
    }

    private func checkNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationsOff = settings.authorizationStatus == .denied && !routines.isEmpty
    }
}

private struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(routine.startText).font(.title2.monospacedDigit().weight(.semibold))
                if routine.blocks && routine.isBlockValid {
                    Text("→ \(routine.endText)").font(.title2.monospacedDigit()).foregroundStyle(.secondary)
                }
                Spacer()
                if routine.blocks { Image(systemName: "lock.fill").foregroundStyle(.secondary) }
            }
            Text(routine.title).font(.headline)
            Text(routine.daysText).font(.subheadline).foregroundStyle(.secondary)
        }
        .opacity(routine.enabled ? 1 : 0.45)
        .padding(.vertical, 4)
    }
}

/// Adds or edits one routine: the reminder, its days and what it blocks until when.
private struct RoutineEditor: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var routine: Routine
    let isNew: Bool
    let onSave: (Routine) -> Void
    let onDelete: () -> Void

    @State private var selection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var showPicker = false
    @State private var siteInput = ""
    @State private var siteError: String?
    @State private var requesting = false

    private static let maxSites = 10
    private var authorized: Bool { model.screenTime.isAuthorized }
    private var pickedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count + selection.webDomainTokens.count
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $routine.title)
                    TextField("Message", text: $routine.message, axis: .vertical)
                        .lineLimit(1...4)
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("This is what the notification says.")
                }

                Section {
                    DatePicker("Time", selection: time(\.hour, \.minute), displayedComponents: .hourAndMinute)
                    WeekdayPicker(weekdays: $routine.weekdays)
                    if !isNew { Toggle("On", isOn: $routine.enabled) }
                } header: {
                    Text("When")
                }

                blockSection

                if !isNew {
                    Section {
                        Button("Delete routine", role: .destructive) { onDelete(); dismiss() }
                    }
                }
            }
            .navigationTitle(isNew ? "New routine" : "Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!canSave)
                }
            }
        }
        .familyActivityPicker(headerText: "Pick the apps to block during this routine",
                              isPresented: $showPicker, selection: $selection)
        .onAppear { selection = RoutineSelections.load(routine.id) }
    }

    @ViewBuilder private var blockSection: some View {
        Section {
            Toggle("Block apps and websites", isOn: $routine.blocks)
            if routine.blocks {
                DatePicker("Until", selection: time(\.endHour, \.endMinute), displayedComponents: .hourAndMinute)
                if !routine.isBlockValid {
                    Text("The block needs to last at least \(Routine.minimumBlockMinutes) minutes.")
                        .font(.footnote).foregroundStyle(.red)
                }
                if authorized {
                    Button { showPicker = true } label: {
                        HStack {
                            Label("Apps", systemImage: "square.grid.2x2")
                            Spacer()
                            Text(pickedCount == 0 ? "Choose" : "\(pickedCount) selected").foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                } else {
                    Button(requesting ? "Opening…" : "Allow Screen Time access") { requestAccess() }
                        .disabled(requesting)
                }
            }
        } header: {
            Text("Block")
        } footer: {
            if routine.blocks {
                Text(authorized
                     ? "From \(routine.startText) until \(routine.endText) the apps and websites you pick stay closed, with no unblock. Turn the routine off to get them back sooner."
                     : "iOS only lets Brain Health block apps and websites with Screen Time access.")
            }
        }

        if routine.blocks && authorized {
            Section {
                HStack {
                    TextField("youtube.com", text: $siteInput)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit(addSite)
                    Button("Add", action: addSite)
                        .disabled(siteInput.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if let siteError {
                    Text(siteError).font(.footnote).foregroundStyle(.red)
                }
                ForEach(routine.sites, id: \.self) { Label($0, systemImage: "globe") }
                    .onDelete { routine.sites.remove(atOffsets: $0) }
            } header: {
                Text("Websites")
            } footer: {
                Text("Blocked in every browser during the routine. Paste a link or type a domain. Up to \(Self.maxSites).")
            }
        }
    }

    private var canSave: Bool {
        !routine.title.trimmingCharacters(in: .whitespaces).isEmpty && !routine.weekdays.isEmpty
            && (!routine.blocks || routine.isBlockValid)
    }

    /// A Date binding over an hour/minute pair of the routine, for DatePicker.
    private func time(_ hour: WritableKeyPath<Routine, Int>, _ minute: WritableKeyPath<Routine, Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(from: DateComponents(hour: routine[keyPath: hour], minute: routine[keyPath: minute])) ?? Date() },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                routine[keyPath: hour] = c.hour ?? 0
                routine[keyPath: minute] = c.minute ?? 0
            })
    }

    private func addSite() {
        guard let domain = BlockedSites.normalize(siteInput) else {
            siteError = "That doesn't look like a website. Try something like youtube.com."
            return
        }
        if !routine.sites.contains(domain) {
            guard routine.sites.count < Self.maxSites else {
                siteError = "A routine can block up to \(Self.maxSites) websites."
                return
            }
            routine.sites.append(domain)
        }
        siteInput = ""
        siteError = nil
    }

    private func save() {
        routine.title = routine.title.trimmingCharacters(in: .whitespacesAndNewlines)
        routine.message = routine.message.trimmingCharacters(in: .whitespacesAndNewlines)
        RoutineSelections.save(selection, for: routine.id)
        onSave(routine)
        dismiss()
    }

    private func requestAccess() {
        requesting = true
        Task {
            _ = await model.screenTime.requestAuthorization()
            requesting = false
        }
    }
}

/// Seven round day toggles in the order the user's week starts.
private struct WeekdayPicker: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        HStack {
            ForEach(Routine.weekOrder, id: \.self) { day in
                let on = weekdays.contains(day)
                Button {
                    if on { weekdays.remove(day) } else { weekdays.insert(day) }
                } label: {
                    Text(symbols[day - 1])
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 34, height: 34)
                        .background(on ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(on ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                .accessibilityAddTraits(on ? .isSelected : [])
                if day != Routine.weekOrder.last { Spacer(minLength: 0) }
            }
        }
        .padding(.vertical, 4)
    }
}
