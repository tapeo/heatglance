import Charts
import Foundation
import SwiftUI

import HeatGlanceCore

struct HistoryMetricChart: View {
    struct Series: Identifiable {
        let id: String
        let name: String
        let color: Color
        let value: (HistoryBucket) -> Double?
    }

    struct Shade: Identifiable {
        let interval: DateInterval
        let color: Color
        let kind: String

        var id: String {
            "\(kind)-\(interval.start.timeIntervalSince1970)"
        }
    }

    let title: String
    let buckets: [HistoryBucket]
    let series: [Series]
    let shades: [Shade]
    let domain: DateInterval
    @Binding var selectedDate: Date?
    var usesSteps = false
    var fixedYDomain: ClosedRange<Double>? = nil
    var yLabels: [Double: String] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.semibold))
            Chart {
                ForEach(shades) { shade in
                    RectangleMark(
                        xStart: .value("Start", shade.interval.start),
                        xEnd: .value("End", shade.interval.end)
                    )
                    .foregroundStyle(shade.color.opacity(0.15))
                }
                ForEach(series) { line in
                    ForEach(entries(for: line)) { entry in
                        LineMark(
                            x: .value("Time", entry.bucket.start),
                            y: .value(line.name, entry.value),
                            series: .value("Segment", "\(line.id)-\(entry.bucket.segment)")
                        )
                        .foregroundStyle(line.color)
                        .interpolationMethod(interpolation)
                        .lineStyle(StrokeStyle(lineWidth: 1.4))
                    }
                }
                if let selectedDate {
                    RuleMark(x: .value("Selected", selectedDate))
                        .foregroundStyle(.secondary.opacity(0.4))
                }
            }
            .chartXScale(domain: domain.start...domain.end)
            .chartXSelection(value: $selectedDate)
            .chartYScale(domain: resolvedYDomain)
            .chartYAxis {
                AxisMarks(position: .trailing, values: axisTicks) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        Text(tickText(value.as(Double.self) ?? 0))
                            .frame(width: 58, alignment: .leading)
                    }
                }
            }
            .frame(height: 90)
        }
    }

    private struct Entry: Identifiable {
        let bucket: HistoryBucket
        let value: Double
        var id: Date { bucket.start }
    }

    private var interpolation: InterpolationMethod {
        if usesSteps {
            return .stepEnd
        }
        return .linear
    }

    private var resolvedYDomain: ClosedRange<Double> {
        if let fixedYDomain {
            return fixedYDomain
        }
        let values = series.flatMap { line in entries(for: line).map(\.value) }
        guard let low = values.min(), let high = values.max() else {
            return 0...1
        }
        if low == high {
            let padding = max(abs(low) * 0.1, 1)
            return (low - padding)...(high + padding)
        }
        let padding = (high - low) * 0.1
        return max(low - padding, 0)...(high + padding)
    }

    private func entries(for line: Series) -> [Entry] {
        buckets.compactMap { bucket in
            guard let value = line.value(bucket) else {
                return nil
            }
            return Entry(bucket: bucket, value: value)
        }
    }

    private var axisTicks: [Double] {
        if yLabels.isEmpty {
            let bounds = resolvedYDomain
            return [bounds.lowerBound, (bounds.lowerBound + bounds.upperBound) / 2, bounds.upperBound]
        }
        return yLabels.keys.sorted()
    }

    private func numberText(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    private func tickText(_ value: Double) -> String {
        yLabels[value] ?? numberText(value)
    }
}
