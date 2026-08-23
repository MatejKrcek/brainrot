import WidgetKit
import SwiftUI

struct BrainEntry: TimelineEntry {
    let date: Date
    let snap: RotSnapshot
}

struct BrainProvider: TimelineProvider {
    func placeholder(in context: Context) -> BrainEntry { BrainEntry(date: .now, snap: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (BrainEntry) -> Void) {
        completion(BrainEntry(date: .now, snap: context.isPreview ? .placeholder : SharedStore.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BrainEntry>) -> Void) {
        let snap = SharedStore.snapshot()
        var entries = [BrainEntry(date: .now, snap: snap)]
        // If an unlock window is open, add an entry right after it ends so the chip flips.
        if let until = snap.unlockUntil, until > .now {
            var after = snap; after.unlockUntil = nil
            entries.append(BrainEntry(date: until.addingTimeInterval(1), snap: after))
        }
        // Also refresh at midnight so the brain resets visually.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        entries.append(BrainEntry(date: midnight, snap: RotSnapshot(minutes: 0, limit: snap.limit, streak: snap.streak,
                                                                    mode: snap.mode, isShielded: snap.isShielded,
                                                                    unlockUntil: nil, isMonitoring: snap.isMonitoring,
                                                                    challengesDone: snap.challengesDone, coachMessage: nil)))
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

// MARK: - Home screen widget

struct BrainWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: BrainEntry

    var body: some View {
        switch family {
        case .systemSmall: small.padding(14)
        case .systemMedium: medium.padding(14)
        case .systemLarge: large.padding(16)
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    private var snap: RotSnapshot { entry.snap }

    private var statusChip: some View {
        HStack(spacing: 4) {
            Image(systemName: snap.isUnlocked ? "lock.open.fill" : (snap.isShielded ? "lock.fill" : "eye"))
            if snap.isUnlocked, let u = snap.unlockUntil {
                Text("until \(u, style: .time)")
            } else {
                Text(snap.isShielded ? "Locked" : (snap.isMonitoring ? "Tracking" : "Off"))
            }
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(snap.isUnlocked ? Theme.acid : .white.opacity(0.8))
        .padding(.horizontal, 7).padding(.vertical, 4)
        .background(Capsule().fill(.white.opacity(0.1)))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                Text("\(snap.rotPercent)%")
                    .font(.display(30))
                    .foregroundStyle(Theme.rotColor(snap.rot))
                    .minimumScaleFactor(0.7)
                Spacer()
                BrainView(rot: snap.rot, glow: false).frame(width: 58, height: 58).offset(x: 6, y: -6)
            }
            Spacer(minLength: 0)
            Text(snap.stage.title.uppercased())
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
                .tracking(1.5)
            Text("\(snap.minutes.asDuration) / \(snap.limit.asDuration)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Spacer(minLength: 6)
            statusChip
        }
        .widgetURL(DeepLink.home)
    }

    private var medium: some View {
        HStack(spacing: 14) {
            BrainView(rot: snap.rot, glow: true).frame(width: 108, height: 108)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(snap.rotPercent)%")
                        .font(.display(32))
                        .foregroundStyle(Theme.rotColor(snap.rot))
                    Text("rotten").font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(snap.stage.tagline)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
                Spacer(minLength: 2)
                ProgressBar(fraction: min(1, snap.ratio), tint: Theme.rotColor(snap.rot))
                    .frame(height: 6)
                HStack {
                    Text("\(snap.minutes.asDuration) of \(snap.limit.asDuration)")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill").foregroundStyle(Theme.acid)
                        Text("\(snap.streak)")
                    }.font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    statusChip
                }
            }
        }
        .widgetURL(DeepLink.home)
    }

    private var large: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("BRAINROT").font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(2)
                        .foregroundStyle(.white.opacity(0.45))
                    Text("\(snap.rotPercent)% \(snap.stage.title.lowercased())")
                        .font(.display(24)).foregroundStyle(Theme.rotColor(snap.rot))
                }
                Spacer()
                statusChip
            }
            BrainView(rot: snap.rot).frame(maxWidth: .infinity).frame(height: 150)
            Text(snap.coachMessage ?? snap.stage.tagline)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            ProgressBar(fraction: min(1, snap.ratio), tint: Theme.rotColor(snap.rot)).frame(height: 8)
            HStack {
                stat("\(snap.minutes.asDuration)", "today")
                Spacer()
                stat("\(snap.limit.asDuration)", "limit")
                Spacer()
                stat("\(snap.streak)", "streak")
                Spacer()
                stat("\(snap.challengesDone)", "earned")
            }
            Link(destination: DeepLink.challenge) {
                Text(snap.isUnlocked ? "Unlocked · tap to extend" : "Earn \(SharedStore.unlockMinutes) min")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Capsule().fill(Theme.acid))
            }
        }
        .widgetURL(DeepLink.home)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 0) {
            Text(value).font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(label.uppercased()).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.45)).tracking(1)
        }
    }

    // MARK: Lock screen

    private var circular: some View {
        Gauge(value: min(1, snap.ratio)) {
            Text("🧠")
        } currentValueLabel: {
            Text("\(snap.rotPercent)%").font(.system(size: 13, weight: .heavy, design: .rounded))
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(DeepLink.home)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            BrainView(rot: snap.rot, glow: false).frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("Brain \(snap.rotPercent)% rotten").font(.system(size: 14, weight: .heavy, design: .rounded))
                Text("\(snap.minutes.asDuration) / \(snap.limit.asDuration) · \(snap.stage.title)")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).opacity(0.8)
                Gauge(value: min(1, snap.ratio)) { EmptyView() }.gaugeStyle(.accessoryLinearCapacity)
            }
        }
        .widgetURL(DeepLink.home)
    }

    private var inline: some View {
        Text("🧠 \(snap.rotPercent)% rotten · \(snap.minutes.asDuration)")
            .widgetURL(DeepLink.home)
    }
}

struct ProgressBar: View {
    var fraction: Double
    var tint: Color
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.1))
                Capsule().fill(tint).frame(width: max(6, geo.size.width * fraction))
            }
        }
    }
}

struct BrainrotWidget: Widget {
    let kind = "BrainrotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BrainProvider()) { entry in
            BrainWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    Theme.bg
                }
        }
        .configurationDisplayName("Brain status")
        .description("How rotten is it today?")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

@main
struct BrainrotWidgetBundle: WidgetBundle {
    var body: some Widget {
        BrainrotWidget()
    }
}

#Preview(as: .systemSmall) { BrainrotWidget() } timeline: {
    BrainEntry(date: .now, snap: .placeholder)
}
#Preview(as: .systemMedium) { BrainrotWidget() } timeline: {
    BrainEntry(date: .now, snap: .placeholder)
}
#Preview(as: .systemLarge) { BrainrotWidget() } timeline: {
    BrainEntry(date: .now, snap: .placeholder)
}
