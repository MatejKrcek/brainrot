import SwiftUI
import DeviceActivity
import FamilyControls

struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    @State private var coachLine: String?

    private var snap: RotSnapshot { model.snap }

    var body: some View {
        Screen {
            ScrollView {
                VStack(spacing: 16) {
                    topBar
                    hero
                    usageCard
                    unlockButton
                    coachCard
                    if model.screenTime.isAuthorized && SharedStore.isMonitoring {
                        exactUsage
                    } else {
                        demoCard
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
            .refreshable { model.refresh() }
        }
        .onAppear { model.refresh() }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("BRAINROT").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(3)
                    .foregroundStyle(Theme.textDim)
                Text(Date(), format: .dateTime.weekday(.wide).day().month())
                    .font(.display(20)).foregroundStyle(.white)
            }
            Spacer()
            Chip(text: "\(snap.streak) day streak", symbol: "flame.fill", tint: snap.streak > 0 ? Theme.acid : Theme.textDim)
        }
        .padding(.top, 8)
    }

    private var hero: some View {
        VStack(spacing: 6) {
            AnimatedBrainView(rot: snap.rot)
                .frame(height: 250)
                .padding(.top, 8)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(snap.rotPercent)%")
                    .font(.display(56))
                    .foregroundStyle(Theme.rotColor(snap.rot))
                    .contentTransition(.numericText())
                Text("rotten").font(.display(20, weight: .bold)).foregroundStyle(Theme.textDim)
            }
            Text("\(snap.stage.emoji) \(snap.stage.title) · \(snap.stage.tagline)")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(duration: 0.6), value: snap.rotPercent)
    }

    private var usageCard: some View {
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text(snap.minutes.asDuration).font(.display(28)).foregroundStyle(.white)
                Text("of \(snap.limit.asDuration) today").font(.system(.subheadline, design: .rounded)).foregroundStyle(Theme.textDim)
                Spacer()
                statusChip
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [Theme.pink, Theme.rotColor(snap.rot)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * min(1, snap.ratio)))
                        .animation(.spring(duration: 0.6), value: snap.ratio)
                }
            }
            .frame(height: 10)
            HStack {
                Text(snap.minutesLeft == 0 ? "Limit blown. Everything past here is liquefaction."
                                           : "\(snap.minutesLeft.asDuration) left before full rot.")
                    .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                Spacer()
                Text(snap.mode.title).font(.system(.caption, design: .rounded).weight(.bold)).foregroundStyle(Theme.textDim)
            }
        }
    }

    private var statusChip: some View {
        Group {
            if snap.isUnlocked, let u = snap.unlockUntil {
                Chip(text: "Open until \(u.formatted(date: .omitted, time: .shortened))", symbol: "lock.open.fill", tint: Theme.acid)
            } else if snap.isShielded {
                Chip(text: "Locked", symbol: "lock.fill", tint: Theme.pink)
            } else if snap.isMonitoring {
                Chip(text: "Tracking", symbol: "eye.fill", tint: .white)
            } else {
                Chip(text: SharedStore.demoMode ? "Demo" : "Off", symbol: "pause.circle", tint: Theme.textDim)
            }
        }
    }

    private var unlockButton: some View {
        VStack(spacing: 8) {
            PrimaryButton(title: snap.isUnlocked ? "Extend by \(SharedStore.unlockMinutes) min" : "Earn \(SharedStore.unlockMinutes) min of scrolling",
                          symbol: snap.isUnlocked ? "plus" : "lock.open.fill") {
                model.showChallenge = true
            }
            Text(snap.mode == .gate ? "Apps stay locked until you pass a challenge."
                                    : "After the limit, every extra minute costs a challenge.")
                .font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
        }
    }

    private var coachCard: some View {
        Button { model.tab = .coach } label: {
            Card {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "stethoscope").font(.title3).foregroundStyle(Theme.violet)
                        .frame(width: 36, height: 36).background(Circle().fill(Theme.violet.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dr. Brain says").font(.system(.caption, design: .rounded).weight(.heavy)).tracking(1)
                            .foregroundStyle(Theme.textDim)
                        Text(snap.coachMessage ?? Roasts.line(for: snap, language: SharedStore.coachLanguage))
                            .font(.system(.subheadline, design: .rounded)).foregroundStyle(.white)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Theme.textDim)
                }
            }
        }.buttonStyle(.plain)
    }

    private var exactUsage: some View {
        let sel = model.screenTime.selection
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let filter = DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: start, end: Date())),
            users: .all,
            devices: .init([.iPhone]),
            applications: sel.applicationTokens,
            categories: sel.categoryTokens,
            webDomains: sel.webDomainTokens)
        return DeviceActivityReport(DeviceActivityReport.Context("Today"), filter: filter)
            .frame(minHeight: 120)
    }

    private var demoCard: some View {
        Card {
            HStack {
                Image(systemName: "wand.and.stars").foregroundStyle(Theme.acid)
                Text("Demo mode").font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                Spacer()
            }
            Text(model.screenTime.isAuthorized
                 ? "Monitoring is off. Turn it on in Settings to track real usage."
                 : "Screen Time isn't authorized (needs a paid Apple Developer team on a real iPhone). Simulate scrolling to see the brain and widgets react.")
                .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
            HStack(spacing: 8) {
                ForEach([5, 15, 30], id: \.self) { m in
                    Button("+\(m)m") { model.demoAddMinutes(m) }
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.black).padding(.vertical, 8).frame(maxWidth: .infinity)
                        .background(Capsule().fill(Theme.acid))
                }
                Button("Reset") { model.demoAddMinutes(-SharedStore.minutesToday) }
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white).padding(.vertical, 8).frame(maxWidth: .infinity)
                    .background(Capsule().fill(.white.opacity(0.1)))
            }.buttonStyle(.plain)
        }
    }
}
