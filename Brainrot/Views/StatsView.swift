import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var model: AppModel
    @State private var days: [(day: Date, minutes: Int)] = []

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stats").font(.display(34)).foregroundStyle(.white).padding(.top, 8)
                    chartCard
                    HStack(spacing: 10) {
                        StatTile(value: avg.asDuration, label: "avg / day")
                        StatTile(value: total.asDuration, label: "this week")
                    }
                    HStack(spacing: 10) {
                        StatTile(value: "\(model.snap.streak)", label: "day streak", tint: Theme.acid)
                        StatTile(value: "\(model.snap.challengesDone)", label: "challenges passed", tint: Theme.violet)
                    }
                    daysUnder
                    rotScale
                }
                .padding(.horizontal, 18).padding(.bottom, 30)
            }
        }
        .onAppear { days = SharedStore.recentDays(7) }
        .onReceive(model.$snap) { _ in days = SharedStore.recentDays(7) }
    }

    private var total: Int { days.map(\.minutes).reduce(0, +) }
    private var avg: Int { days.isEmpty ? 0 : total / days.count }
    private var under: Int { days.filter { $0.minutes <= model.snap.limit }.count }

    private var chartCard: some View {
        Card {
            SectionTitle(text: "Last 7 days")
            Chart {
                ForEach(days, id: \.day) { d in
                    BarMark(x: .value("Day", d.day, unit: .day), y: .value("Minutes", d.minutes))
                        .foregroundStyle(d.minutes > model.snap.limit ? Theme.pink : Theme.acid)
                        .cornerRadius(6)
                }
                RuleMark(y: .value("Limit", model.snap.limit))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(.white.opacity(0.5))
                    .annotation(position: .top, alignment: .trailing) {
                        Text("limit").font(.system(.caption2, design: .rounded)).foregroundStyle(Theme.textDim)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisValueLabel(format: .dateTime.weekday(.narrow), centered: true)
                        .foregroundStyle(Theme.textDim)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisGridLine().foregroundStyle(.white.opacity(0.06))
                    AxisValueLabel {
                        if let m = v.as(Int.self) { Text(m.asDuration).font(.system(.caption2, design: .rounded)).foregroundStyle(Theme.textDim) }
                    }
                }
            }
            .frame(height: 200)
        }
    }

    private var daysUnder: some View {
        Card {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(under) of \(days.count) days under the limit")
                        .font(.system(.body, design: .rounded).weight(.bold)).foregroundStyle(.white)
                    Text(under >= 5 ? "Disciplined. Suspiciously so." : (under >= 3 ? "Half-rotten week. Could be worse." : "Full compost. Let's fix that."))
                        .font(.system(.footnote, design: .rounded)).foregroundStyle(Theme.textDim)
                }
                Spacer()
                HStack(spacing: 4) {
                    ForEach(days, id: \.day) { d in
                        Circle().fill(d.minutes <= model.snap.limit ? Theme.acid : Theme.pink).frame(width: 10, height: 10)
                    }
                }
            }
        }
    }

    private var rotScale: some View {
        Card {
            SectionTitle(text: "Rot scale")
            ForEach(RotStage.allCases, id: \.rawValue) { s in
                HStack(spacing: 12) {
                    BrainView(rot: Double(s.rawValue) / 4.0, glow: false).frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(s.title) \(s.emoji)").font(.system(.subheadline, design: .rounded).weight(.bold)).foregroundStyle(.white)
                        Text(s.tagline).font(.system(.caption, design: .rounded)).foregroundStyle(Theme.textDim)
                    }
                    Spacer()
                    Text(rangeLabel(s)).font(.system(.caption, design: .rounded).weight(.semibold).monospacedDigit()).foregroundStyle(Theme.textDim)
                }
            }
        }
    }

    private func rangeLabel(_ s: RotStage) -> String {
        switch s {
        case .fresh: return "0–24%"
        case .mushy: return "25–49%"
        case .rotting: return "50–74%"
        case .decayed: return "75–99%"
        case .liquefied: return "100%+"
        }
    }
}
