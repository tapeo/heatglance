import Charts
import SwiftUI

import HeatGlanceCore

struct HistoryView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
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
                .frame(minHeight: 200)

                Text("Worst process: \(latestWorst)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
        .frame(minWidth: 480, minHeight: 320)
    }

    private var latestWorst: String {
        guard let point = monitor.history.points.last, let name = point.worstGroupName else {
            return "none"
        }
        return "\(name) at \(Int(point.worstGroupCPU))%"
    }
}
