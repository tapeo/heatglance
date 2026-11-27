import SwiftUI

import HeatGlanceCore

struct WeeklyReportView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        let report = monitor.trends.summaries.week(endingAt: Date())
        VStack(alignment: .leading, spacing: 12) {
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
                            .foregroundStyle(changeColor(change))
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
    }

    private func changeColor(_ change: Double) -> Color {
        if change > 0 {
            return .orange
        }
        return .green
    }
}
