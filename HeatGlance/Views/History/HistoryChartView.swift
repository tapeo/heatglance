import Charts
import Foundation
import SwiftUI

import HeatGlanceCore

struct HistoryChartView: View {
    @Environment(Monitor.self) private var monitor
    @State private var window = HistoryWindow.recent(.day)
    @State private var selectedDate: Date?
    @State private var buckets: [HistoryBucket] = []
    @State private var awaySpans: [DateInterval] = []
    @State private var pausedSpans: [DateInterval] = []
    @State private var domain = DateInterval(start: Date(), duration: 86_400)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HistoryWindowPicker(window: $window)
            legend
            HistoryDetailView(
                bucket: selectedBucket,
                window: window,
                events: selectedEvents,
                isHovering: selectedDate != nil
            )
            content
        }
        .task(id: refreshID) {
            updateSeries()
        }
        .onChange(of: window) {
            selectedDate = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if monitor.history.points.isEmpty {
            Text("History builds up while HeatGlance runs.")
                .foregroundStyle(.secondary)
            Spacer()
        } else if buckets.isEmpty {
            Text(emptyText)
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 14) {
                    thermalPanel
                    if hasTemperature {
                        temperaturePanel
                    }
                    cpuPanel
                    swapPanel
                    diskPanel
                }
            }
        }
    }

    private var thermalPanel: some View {
        HistoryMetricChart(
            title: "Thermal and memory pressure",
            buckets: buckets,
            series: [
                HistoryMetricChart.Series(id: "thermal", name: "Thermal", color: .orange) { bucket in
                    Double(bucket.thermal.rawValue)
                },
                HistoryMetricChart.Series(id: "memory", name: "Memory pressure", color: .purple) { bucket in
                    Double(bucket.memoryPressure.rawValue)
                },
            ],
            shades: shades,
            domain: domain,
            selectedDate: $selectedDate,
            usesSteps: true,
            fixedYDomain: 0...3,
            yLabels: [0: "Nominal", 1: "Fair", 2: "Serious", 3: "Critical"]
        )
    }

    private var temperaturePanel: some View {
        HistoryMetricChart(
            title: "Temperature, °C",
            buckets: buckets,
            series: [
                HistoryMetricChart.Series(id: "temperature", name: "Temperature", color: .red) { bucket in
                    bucket.temperatureCelsius
                },
            ],
            shades: shades,
            domain: domain,
            selectedDate: $selectedDate
        )
    }

    private var cpuPanel: some View {
        HistoryMetricChart(
            title: "CPU, %",
            buckets: buckets,
            series: [
                HistoryMetricChart.Series(id: "cpu", name: "CPU", color: .blue) { bucket in
                    bucket.systemCPUPercent
                },
            ],
            shades: shades,
            domain: domain,
            selectedDate: $selectedDate
        )
    }

    private var swapPanel: some View {
        HistoryMetricChart(
            title: "Swap, GB",
            buckets: buckets,
            series: [
                HistoryMetricChart.Series(id: "swap", name: "Swap", color: .teal) { bucket in
                    Double(bucket.swapUsedBytes) / 1_073_741_824
                },
            ],
            shades: shades,
            domain: domain,
            selectedDate: $selectedDate
        )
    }

    private var diskPanel: some View {
        HistoryMetricChart(
            title: "Free disk, GB",
            buckets: buckets,
            series: [
                HistoryMetricChart.Series(id: "disk", name: "Free disk", color: .green) { bucket in
                    Double(bucket.diskAvailableBytes) / 1_073_741_824
                },
            ],
            shades: shades,
            domain: domain,
            selectedDate: $selectedDate
        )
    }

    private var legend: some View {
        HStack(spacing: 12) {
            legendItem("Away", color: .gray)
            legendItem("Apps paused", color: .orange)
        }
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.35))
                .frame(width: 12, height: 8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var hasTemperature: Bool {
        buckets.contains { $0.temperatureCelsius != nil }
    }

    private var shades: [HistoryMetricChart.Shade] {
        let away = awaySpans.map { HistoryMetricChart.Shade(interval: $0, color: .gray, kind: "away") }
        let paused = pausedSpans.map { HistoryMetricChart.Shade(interval: $0, color: .orange, kind: "paused") }
        return away + paused
    }

    private var emptyText: String {
        if case .day = window {
            return "No data for this day"
        }
        return "No data in this range"
    }

    private var selectedBucket: HistoryBucket? {
        guard let selectedDate else {
            return buckets.last
        }
        return HistorySeries.bucket(at: selectedDate, in: buckets)
    }

    private var selectedEvents: [HistoryEvent] {
        guard let selectedBucket else {
            return []
        }
        let interval = DateInterval(start: selectedBucket.start, end: selectedBucket.end)
        return Array(monitor.eventLog.events(in: interval).suffix(3))
    }

    private var refreshID: HistoryRefreshKey {
        HistoryRefreshKey(window: window, lastMinute: monitor.history.points.last?.minute)
    }

    private func updateSeries() {
        let now = Date()
        let fresh = HistorySeries.buckets(points: monitor.history.points, window: window, now: now)
        buckets = fresh
        awaySpans = HistorySeries.spans(fresh) { $0.isAway }
        pausedSpans = HistorySeries.spans(fresh) { $0.pausedApps > 0 }
        domain = window.interval(now: now)
    }
}

private struct HistoryRefreshKey: Hashable {
    let window: HistoryWindow
    let lastMinute: Date?
}
