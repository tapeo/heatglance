import Foundation
import SwiftUI

import HeatGlanceCore

struct HistoryDetailView: View {
    let bucket: HistoryBucket?
    let window: HistoryWindow
    let events: [HistoryEvent]
    let isHovering: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let bucket {
                Text(timeText(bucket))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(metricsText(bucket))
                    .font(.callout.monospacedDigit())
                    .lineLimit(1)
                Text(secondaryText(bucket))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                ForEach(events) { event in
                    Text(eventText(event))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else if isHovering {
                Text("No data for this time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: 110, alignment: .topLeading)
    }

    private func timeText(_ bucket: HistoryBucket) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: bucket.start)

        let label: String
        if bucket.end.timeIntervalSince(bucket.start) > 90 {
            label = "\(start) to \(formatter.string(from: bucket.end))"
        } else {
            label = start
        }

        if case .recent = window, !Calendar.current.isDateInToday(bucket.start) {
            let dayFormatter = DateFormatter()
            dayFormatter.locale = Locale(identifier: "en_US_POSIX")
            dayFormatter.dateFormat = "MMM d"
            return "\(dayFormatter.string(from: bucket.start)), \(label)"
        }
        return label
    }

    private func metricsText(_ bucket: HistoryBucket) -> String {
        var parts = [bucket.thermal.title]
        if let temperature = bucket.temperatureCelsius {
            parts.append(String(format: "%.0f °C", temperature))
        }
        parts.append(bucket.memoryPressure.title)
        parts.append("CPU \(percent(bucket.systemCPUPercent))")
        parts.append("Swap \(gigabytes(Double(bucket.swapUsedBytes))) GB")
        parts.append("Free \(gigabytes(Double(bucket.diskAvailableBytes))) GB")
        return parts.joined(separator: " · ")
    }

    private func secondaryText(_ bucket: HistoryBucket) -> String {
        var parts: [String] = []
        if let name = bucket.worstGroupName {
            parts.append("\(name) at \(percent(bucket.worstGroupCPU))")
        }
        if bucket.isAway {
            parts.append("Away")
        }
        if bucket.pausedApps > 0 {
            parts.append("\(bucket.pausedApps) apps paused")
        }
        return parts.joined(separator: " · ")
    }

    private func eventText(_ event: HistoryEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        var text = "\(formatter.string(from: event.date))  \(event.kind.title): \(event.title)"
        if let value = event.value {
            text += ", \(value)"
        }
        return text
    }

    private func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func gigabytes(_ bytes: Double) -> String {
        String(format: "%.1f", bytes / 1_073_741_824)
    }
}
