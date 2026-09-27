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
        // Midnight reset so the brain recovers visually without waiting for the extension.
        let midnight = Calendar.current.startOfDay(for: .now.addingTimeInterval(86_400))
        var fresh = snap; fresh.minutes = 0; fresh.unlockUntil = nil
        entries.append(BrainEntry(date: midnight, snap: fresh))
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

/// Just the brain. Health is communicated by the tissue itself.
struct BrainWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: BrainEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular:
                BrainView(rot: entry.snap.rot, glow: false)
                    .padding(2)
            case .accessoryRectangular:
                BrainView(rot: entry.snap.rot, glow: false)
                    .padding(4)
            default:
                BrainView(rot: entry.snap.rot, glow: renderingMode == .fullColor)
                    .padding(family == .systemSmall ? 12 : 18)
            }
        }
        .widgetAccentable()
        .widgetURL(DeepLink.home)
        .accessibilityLabel("Brain health \(entry.snap.healthPercent) percent")
    }
}

struct GrayMatterWidget: Widget {
    let kind = "GrayMatterBrain"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BrainProvider()) { entry in
            BrainWidgetView(entry: entry)
                .containerBackground(for: .widget) { Color(.systemBackground) }
        }
        .configurationDisplayName("Brain")
        .description("Your brain, as healthy as today's screen time allows.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct GrayMatterWidgetBundle: WidgetBundle {
    var body: some Widget {
        HealthWidget()
        GrayMatterWidget()
    }
}

#Preview(as: .systemSmall) { GrayMatterWidget() } timeline: {
    BrainEntry(date: .now, snap: .placeholder)
    BrainEntry(date: .now, snap: RotSnapshot(minutes: 70, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: true))
}
