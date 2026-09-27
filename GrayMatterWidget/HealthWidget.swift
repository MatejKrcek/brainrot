import WidgetKit
import SwiftUI

/// Brain plus the number: health %, stage and minutes. Same timeline as the brain-only widget.
struct HealthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let entry: BrainEntry

    var body: some View {
        HealthWidgetContent(snap: entry.snap, family: family, glow: renderingMode == .fullColor)
            .widgetAccentable()
            .widgetURL(DeepLink.home)
            .accessibilityLabel("Screen time \(entry.snap.minutes.asDuration), brain \(entry.snap.stage.title)")
    }
}

/// Widget background: system colour plus a soft radial tint in the brain's current colour, so the brain
/// stands off both light and dark Home Screens (same idea as the app icon).
struct WidgetBackdrop: View {
    let rot: Double
    var body: some View {
        ZStack {
            #if canImport(UIKit)
            Color(.systemBackground)
            #else
            Color(nsColor: .windowBackgroundColor)
            #endif
            RadialGradient(colors: [Theme.rotColor(rot).opacity(0.22), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42), startRadius: 0, endRadius: 190)
        }
    }
}

/// Layout per family, with no WidgetKit environment so it can be rendered outside a widget (scripts/preview_widget.swift).
struct HealthWidgetContent: View {
    let snap: RotSnapshot
    let family: WidgetFamily
    var glow = true

    private var tint: Color { Theme.rotColor(snap.rot) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: Text("Screen time \(snap.minutes.asShortDuration) · \(snap.stage.title)")
        case .systemSmall: small
        case .systemMedium: medium
        default: large
        }
    }

    // MARK: Home Screen

    private var small: some View {
        VStack(spacing: 4) {
            BrainView(rot: snap.rot, glow: glow)
                .frame(maxHeight: .infinity)
            Text(snap.minutes.asShortDuration)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(snap.stage.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var medium: some View {
        HStack(spacing: 12) {
            BrainView(rot: snap.rot, glow: glow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.minutes.asShortDuration)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("Screen time · \(snap.stage.title)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                bar
                Text(snap.minutesLeft == 0 ? "Limit \(snap.limit.asShortDuration) reached" : "\(snap.minutesLeft.asShortDuration) left of \(snap.limit.asShortDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let alt = Alternative.headline(snap.minutes) {
                    Text(alt).font(.caption2.italic()).foregroundStyle(.secondary).lineLimit(2).minimumScaleFactor(0.8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
    }

    private var large: some View {
        VStack(spacing: 8) {
            BrainView(rot: snap.rot, glow: glow)
                .frame(maxHeight: .infinity)
            Text(snap.minutes.asDuration)
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text("Screen time today · \(snap.stage.title)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            bar
            Text(snap.minutesLeft == 0
                 ? "Limit of \(snap.limit.asDuration) reached"
                 : "\(snap.minutesLeft.asDuration) left of \(snap.limit.asDuration)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let alt = Alternative.headline(snap.minutes) {
                Text(alt).font(.caption.italic()).foregroundStyle(.secondary).multilineTextAlignment(.center).lineLimit(2)
            }
        }
        .padding(18)
    }

    /// Usage bar: filled share of today's limit, in the brain's current colour.
    private var bar: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(tint).frame(width: g.size.width * min(1, snap.ratio))
            }
        }
        .frame(height: 6)
    }

    // MARK: Lock Screen

    private var circular: some View {
        Gauge(value: Double(snap.healthPercent), in: 0...100) {
            Text("Brain")
        } currentValueLabel: {
            Text(snap.minutes.asShortDuration).font(.system(.caption, design: .rounded).weight(.semibold)).minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var rectangular: some View {
        HStack(spacing: 6) {
            BrainView(rot: snap.rot, glow: false)
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 1) {
                Text(snap.minutes.asShortDuration).font(.headline)
                Text(snap.stage.title).font(.caption2)
                Text(snap.minutesLeft == 0 ? "Limit reached" : "\(snap.minutesLeft.asShortDuration) left")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}

struct HealthWidget: Widget {
    let kind = "GrayMatterHealth"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BrainProvider()) { entry in
            HealthWidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackdrop(rot: entry.snap.rot) }
        }
        .configurationDisplayName("Screen time")
        .description("Your brain with today's screen time and how much is left.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
        .contentMarginsDisabled()
    }
}

#Preview(as: .systemMedium) { HealthWidget() } timeline: {
    BrainEntry(date: .now, snap: .placeholder)
    BrainEntry(date: .now, snap: RotSnapshot(minutes: 70, limit: 60, lockEnabled: false, isShielded: false, unlockUntil: nil, isMonitoring: true))
}
