import Charts
import SwiftUI

import HeatGlanceCore

struct HistoryView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        TabView {
            lastDay
                .tabItem { Label("24 hours", systemImage: "clock") }
            thisWeek
                .tabItem { Label("This week", systemImage: "calendar") }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 360)
    }

    private var lastDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            if monitor.history.points.isEmpty {
                Text("History builds up while HeatGlance runs.")
                    .foregroundStyle(.secondary)
            } else {
                Chart(monitor.history.points(since: Date().addingTimeInterval(-86_400))) { point in
                    LineMark(
                        x: .value("Time", point.minute),
                        y: .value("CPU", point.systemCPUPercent)
                    )
                    .foregroundStyle(by: .value("Metric", "CPU %"))
                }
                .chartYAxisLabel("CPU %")
                .frame(minHeight: 220)

                Text("Worst process: \(latestWorst)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var thisWeek: some View {
        let report = monitor.trends.summaries.week(endingAt: Date())
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                stat("Minutes over serious", "\(report.seriousMinutes)")
                stat("Protection interventions", "\(report.interventions)")
            }
            list("Top CPU", entries: report.topCPU, unit: "points")
            list("Top memory", entries: report.topMemory, unit: "GB")
            list("Top disk writes", entries: report.topWrites, unit: "GB")
            Spacer()
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit())
        }
    }

    private func list(_ title: String, entries: [WeeklyReport.Entry], unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
            if entries.isEmpty {
                Text("Nothing yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(entries) { entry in
                HStack {
                    Text(entry.displayName)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.1f %@", entry.value, unit))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    if let change = entry.change {
                        Text(String(format: "%+.0f%%", change * 100))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(change > 0 ? .orange : .green)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
    }

    private var latestWorst: String {
        guard let point = monitor.history.points.last, let name = point.worstGroupName else {
            return "none"
        }
        return "\(name) at \(Int(point.worstGroupCPU))%"
    }
}
