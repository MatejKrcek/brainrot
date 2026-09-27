import SwiftUI
import DeviceActivity
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmUnblock = false

    private var snap: RotSnapshot { model.snap }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    hero
                    usageCard
                    if model.alternative != nil { insteadCard }
                    if snap.isShielded || snap.isUnlocked { blockCard }
                    if model.screenTime.isAuthorized && SharedStore.isMonitoring {
                        Card(title: "Apps") { exactUsage }
                    } else {
                        demoCard
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Brain Health")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { model.showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .refreshable { model.refresh() }
            .sheet(isPresented: $model.showSettings) { SettingsView().environmentObject(model) }
        }
        .onAppear { model.refresh(); if model.alternative == nil { model.rollAlternative() } }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 12) {
            AnimatedBrainView(rot: snap.rot)
                .frame(height: 230)
                .padding(.top, 4)
            VStack(spacing: 2) {
                Text(snap.minutes.asDuration)
                    .font(.system(size: 56, weight: .semibold))
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.rotColor(snap.rot))
                Text("Screen time today")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text("\(snap.stage.title) · \(snap.stage.summary)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.5), value: snap.minutes)
    }

    // MARK: Usage

    private var usageCard: some View {
        Card(title: "Today") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(snap.minutes.asDuration).font(.title2.weight(.semibold))
                    Text("of \(snap.limit.asDuration)").foregroundStyle(.secondary)
                    Spacer()
                    statusLabel
                }
                ProgressView(value: min(1, snap.ratio))
                    .tint(Theme.rotColor(snap.rot))
                    .animation(.spring(duration: 0.5), value: snap.ratio)
                Text(snap.minutesLeft == 0 ? "Daily limit reached." : "\(snap.minutesLeft.asDuration) left today.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: What the minutes could have been (one quote, different on every open)

    private var insteadCard: some View {
        Card(title: "Instead") {
            if let alt = model.alternative {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "quote.opening")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Theme.rotColor(snap.rot))
                        .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 10) {
                        Text(alt.text(for: snap.minutes))
                            .font(.system(.title3, design: .serif).italic())
                            .fixedSize(horizontal: false, vertical: true)
                        Label("\(snap.minutes.asDuration) of scrolling", systemImage: alt.symbol)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.easeInOut) { model.rollAlternative() } }
            }
        }
    }

    private var statusLabel: some View {
        Group {
            if snap.isUnlocked, let u = snap.unlockUntil {
                Label("Unblocked until \(u.formatted(date: .omitted, time: .shortened))", systemImage: "lock.open")
            } else if snap.isShielded {
                Label("Blocked", systemImage: "lock.fill")
            } else if snap.isMonitoring {
                Label("Tracking", systemImage: "eye")
            } else {
                Label(SharedStore.demoMode ? "Demo" : "Paused", systemImage: "pause.circle")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .labelStyle(.titleAndIcon)
    }

    // MARK: Blocking

    private var blockCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                if snap.isUnlocked {
                    Text("Apps are unblocked for now. They lock again automatically.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("Selected apps are blocked because you're over the limit.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Unblock for \(SharedStore.unlockMinutes) minutes") { confirmUnblock = true }
                        .buttonStyle(.bordered)
                        .confirmationDialog("Unblock apps?", isPresented: $confirmUnblock, titleVisibility: .visible) {
                            Button("Unblock for \(SharedStore.unlockMinutes) minutes") { model.unblock() }
                        } message: { Text("The extra time counts against today's brain health.") }
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: Per-app report (sandboxed extension renders exact numbers)

    private var exactUsage: some View {
        let sel = model.screenTime.selection
        let start = Calendar.current.startOfDay(for: Date())
        let filter = DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: Date())),
            users: .all,
            devices: .init([.iPhone]),
            applications: sel.applicationTokens,
            categories: sel.categoryTokens,
            webDomains: sel.webDomainTokens)
        return DeviceActivityReport(DeviceActivityReport.Context("Today"), filter: filter)
            .frame(minHeight: 100)
            .padding(.horizontal, -16).padding(.vertical, -4)
    }

    private var demoCard: some View {
        Card(title: "Demo") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.screenTime.isAuthorized
                     ? "Tracking is off. Turn it on in Settings."
                     : "Screen Time isn't authorised on this device, so usage is simulated.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Tracking: " + TrackedApp.named(SharedStore.trackedAppIDs).map(\.name).joined(separator: ", "))
                    .font(.footnote).foregroundStyle(.secondary)
                HStack {
                    ForEach([5, 15, 30], id: \.self) { m in
                        Button("+\(m) min") { model.demoAddMinutes(m) }.buttonStyle(.bordered)
                    }
                    Spacer()
                    Button("Reset") { model.demoAddMinutes(-SharedStore.minutesToday) }.buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 10)
        }
    }
}
