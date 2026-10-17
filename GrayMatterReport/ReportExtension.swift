import DeviceActivity
import ManagedSettings
import FamilyControls
import SwiftUI

/// Sandboxed extension that is the only thing allowed to render exact usage numbers.
@main
struct GrayMatterReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TodayReport { model in
            TodayReportView(model: model)
        }
    }
}

extension DeviceActivityReport.Context {
    static let today = Self("Today")
}

struct AppUsage: Identifiable {
    let id = UUID()
    let name: String
    let token: ApplicationToken?
    let seconds: TimeInterval
}

struct TodayReportModel {
    var totalSeconds: TimeInterval = 0
    var apps: [AppUsage] = []
    var pickups: Int = 0
}

struct TodayReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .today
    let content: (TodayReportModel) -> TodayReportView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TodayReportModel {
        var model = TodayReportModel()
        var byName: [String: AppUsage] = [:]
        for await datum in data {
            for await segment in datum.activitySegments {
                model.totalSeconds += segment.totalActivityDuration
                model.pickups += segment.totalPickupsWithoutApplicationActivity
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "Unknown"
                        let prev = byName[name]?.seconds ?? 0
                        byName[name] = AppUsage(name: name, token: app.application.token,
                                                seconds: prev + app.totalActivityDuration)
                    }
                }
            }
        }
        // Under a minute doesn't count: the monitor marks an app as used at one minute, and Home sizes the list from that.
        model.apps = byName.values.filter { $0.seconds >= 60 }.sorted { $0.seconds > $1.seconds }
        return model
    }
}

struct TodayReportView: View {
    let model: TodayReportModel
    /// Fixed row height: the app sizes this remote view from the same metric (see `ReportLayout`).
    @ScaledMetric(relativeTo: .body) private var rowHeight = ReportLayout.rowHeight
    @ScaledMetric(relativeTo: .footnote) private var footerHeight = ReportLayout.footerHeight

    var body: some View {
        GeometryReader { geo in
            let available = geo.size.height - footerHeight - 2 * ReportLayout.verticalPadding
            let fit = max(1, Int(available / rowHeight))
            let apps = model.apps
            // Leave the last row for "+N more" when not everything fits.
            let shown = apps.count > fit ? Array(apps.prefix(max(0, fit - 1))) : apps
            let rest = apps.dropFirst(shown.count)
            // Bars share the Today card's scale: full width is the daily limit.
            let limitSeconds = Double(SharedStore.dailyLimit) * 60

            VStack(alignment: .leading, spacing: 0) {
                if apps.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "moon.zzz").foregroundStyle(.secondary).frame(width: 24)
                        Text("No usage of tracked apps yet today.").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(height: rowHeight)
                }
                ForEach(shown) { app in
                    row(app, share: min(1, app.seconds / limitSeconds)).frame(height: rowHeight)
                }
                if !rest.isEmpty {
                    moreRow(Array(rest), label: shown.isEmpty ? "\(rest.count) apps" : "\(rest.count) more").frame(height: rowHeight)
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(.horizontal, 16).padding(.vertical, ReportLayout.verticalPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ app: AppUsage, share: Double) -> some View {
        HStack(spacing: 12) {
            if let token = app.token {
                Label(token).labelStyle(.iconOnly).frame(width: 30, height: 30)
            } else {
                Image(systemName: "app.fill").font(.title2).foregroundStyle(.secondary).frame(width: 30, height: 30)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(app.name).font(.body).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(duration(app.seconds))
                        .font(.body.weight(.medium).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                GeometryReader { bar in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color(.tertiarySystemFill))
                        Capsule().fill(Theme.rotColor(min(1, share))).frame(width: max(6, bar.size.width * share))
                    }
                }
                .frame(height: 5)
            }
        }
    }

    private func moreRow(_ apps: [AppUsage], label: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "ellipsis.circle").font(.title2).foregroundStyle(.secondary).frame(width: 30, height: 30)
            Text(label).font(.body).foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(duration(apps.reduce(0) { $0 + $1.seconds }))
                .font(.body.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        HStack {
            Text(model.apps.isEmpty ? "Exact numbers from Screen Time"
                                    : "\(model.apps.count) \(model.apps.count == 1 ? "app" : "apps") today")
            Spacer()
            if !model.apps.isEmpty { Text("Total " + duration(model.totalSeconds)).monospacedDigit() }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(height: footerHeight, alignment: .bottom)
    }

    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes == 0 ? "<1 min" : minutes.asDuration
    }
}
