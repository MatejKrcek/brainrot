import DeviceActivity
import ManagedSettings
import FamilyControls
import SwiftUI

/// Sandboxed extension that is the only thing allowed to render exact usage numbers.
@main
struct BrainrotReportExtension: DeviceActivityReportExtension {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exact usage today")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Text(Int(model.totalSeconds / 60).asDuration)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
            }
            if model.apps.isEmpty {
                Text("No usage of tracked apps yet. Suspiciously healthy.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            } else {
                ForEach(model.apps.prefix(6)) { app in
                    HStack(spacing: 10) {
                        if let token = app.token {
                            Label(token).labelStyle(.iconOnly).frame(width: 24, height: 24)
                        } else {
                            Image(systemName: "app.fill").foregroundStyle(.white.opacity(0.4))
                        }
                        Text(app.name)
                            .font(.system(.body, design: .rounded).weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        let minutes = Int(app.seconds / 60)
                        Text(minutes == 0 ? "<1m" : minutes.asDuration)
                            .font(.system(.body, design: .rounded).weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    GeometryReader { geo in
                        let frac = model.totalSeconds > 0 ? app.seconds / model.totalSeconds : 0
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.08))
                            Capsule().fill(Color(red: 0.78, green: 1.0, blue: 0.24))
                                .frame(width: max(4, geo.size.width * frac))
                        }
                    }
                    .frame(height: 5)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(red: 0.09, green: 0.09, blue: 0.125)))
    }
}
