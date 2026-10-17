import SwiftUI
import DeviceActivity
import FamilyControls

struct HomeView: View {
    @EnvironmentObject var model: AppModel
    /// Height of one row in the usage report; the report extension uses the same metric.
    @ScaledMetric(relativeTo: .body) private var reportRowHeight = ReportLayout.rowHeight
    @ScaledMetric(relativeTo: .footnote) private var reportFooterHeight = ReportLayout.footerHeight

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
                    } else if !model.storeMode {
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
            .sheet(isPresented: $model.showUnblockChallenge) { UnblockChallengeView().environmentObject(model) }
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
            } else if snap.isMonitoring || model.storeMode {
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
                    Button { model.showUnblockChallenge = true } label: {
                        Label("Unblock for \(SharedStore.unlockMinutes) minutes", systemImage: "lock.open")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 10)
        }
    }

    // MARK: Per-app report (sandboxed extension renders exact numbers)

    /// The report is a remote view that can't size itself to its content, so it gets an explicit height:
    /// a row per app used today (the monitor extension counts them, see `SharedStore.usedAppsToday`).
    /// A picked category can hold any number of apps the monitor can't count, so it gets a fixed number of rows;
    /// the extension folds anything beyond the rows it has into a "N more" row.
    private var reportRows: Int {
        let sel = model.screenTime.selection
        var rows = SharedStore.usedAppsToday.count
        if !sel.categoryTokens.isEmpty { rows = max(rows, ReportLayout.categoryRows) }
        return min(ReportLayout.maxRows, max(1, rows))
    }

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
        let height = CGFloat(reportRows) * reportRowHeight + reportFooterHeight + 2 * ReportLayout.verticalPadding
        return DeviceActivityReport(DeviceActivityReport.Context("Today"), filter: filter)
            .frame(height: height)
            .padding(.horizontal, -16).padding(.vertical, -4)
    }

    private var demoCard: some View {
        Card(title: "Demo") {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.screenTime.isAuthorized
                     ? "Tracking is off. Turn it on in Settings."
                     : "Screen Time isn't authorised on this device, so usage is simulated.")
                    .font(.subheadline).foregroundStyle(.secondary)
                if !model.screenTime.isAuthorized {
                    Text("Tracking: " + TrackedApp.named(SharedStore.trackedAppIDs).map(\.name).joined(separator: ", "))
                        .font(.footnote).foregroundStyle(.secondary)
                }
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

/// Friction before an unblock: the button has to be tapped `taps` times.
struct UnblockChallengeView: View {
    static let taps = 10

    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var left = Self.taps

    private var progress: Double { Double(Self.taps - left) / Double(Self.taps) }

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 6) {
                Text("Unblock for \(SharedStore.unlockMinutes) minutes?")
                    .font(.title2.bold())
                Text("Tap the circle \(Self.taps) times. The extra time counts against today's brain health.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: tap) {
                ZStack {
                    Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    Circle().trim(from: 0, to: progress)
                        .stroke(Theme.rotColor(model.snap.rot), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(left)")
                            .font(.system(size: 56, weight: .semibold).monospacedDigit())
                            .contentTransition(.numericText(countsDown: true))
                        Text(left == 1 ? "tap left" : "taps left")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 170, height: 170)
                .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .light), trigger: left)
            .accessibilityLabel("Tap to unblock")
            .accessibilityValue("\(left) taps left")
            Button("Keep blocked") { dismiss() }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    private func tap() {
        guard left > 0 else { return }
        withAnimation(.spring(duration: 0.25)) { left -= 1 }
        guard left == 0 else { return }
        model.unblock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { dismiss() }
    }
}
