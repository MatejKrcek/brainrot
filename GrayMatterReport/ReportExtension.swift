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
        model.apps = byName.values.sorted { $0.seconds > $1.seconds }
        return model
    }
}

struct TodayReportView: View {
    let model: TodayReportModel
    /// Fixed row height: the app sizes this remote view from the same metric (see `ReportLayout`).
    @ScaledMetric(relativeTo: .body) private var rowHeight = ReportLayout.rowHeight

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.apps.isEmpty {
                Text("No usage of tracked apps yet today.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(height: rowHeight)
            } else {
                ForEach(model.apps.prefix(ReportLayout.maxRows)) { app in
                    row(app).frame(height: rowHeight)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, ReportLayout.verticalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func row(_ app: AppUsage) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                if let token = app.token {
                    Label(token).labelStyle(.iconOnly).frame(width: 24, height: 24)
                } else {
                    Image(systemName: "app.fill").foregroundStyle(.secondary).frame(width: 24, height: 24)
                }
                Text(app.name)
                    .font(.body)
                    .lineLimit(1)
                Spacer()
                let minutes = Int(app.seconds / 60)
                Text(minutes == 0 ? "<1 min" : minutes.asDuration)
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: model.totalSeconds > 0 ? app.seconds / model.totalSeconds : 0)
                .tint(.accentColor)
        }
    }
}
