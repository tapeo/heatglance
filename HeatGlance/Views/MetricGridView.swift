import Foundation
import SwiftUI

import HeatGlanceCore

struct MetricItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let level: HealthLevel

    init(title: String, value: String, level: HealthLevel) {
        self.id = title
        self.title = title
        self.value = value
        self.level = level
    }
}

struct MetricGridView: View {
    @Environment(Monitor.self) private var monitor

    let sample: Sample

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible()),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                MetricRowView(title: item.title, value: item.value, level: item.level)
            }
        }
    }

    private var items: [MetricItem] {
        [
            MetricItem(
                title: "Thermal",
                value: RuleSummary.thermalText(sample),
                level: sample.thermal.healthLevel
            ),
            MetricItem(
                title: "CPU",
                value: String(format: "%.0f%%", sample.systemCPUPercent),
                level: cpuLevel
            ),
            MetricItem(
                title: "Memory",
                value: sample.memoryPressure.title,
                level: sample.memoryPressure.healthLevel
            ),
            MetricItem(
                title: "Swap",
                value: bytes(sample.swapUsedBytes),
                level: swapLevel
            ),
            MetricItem(
                title: "Disk free",
                value: String(format: "%.1f GB", sample.diskAvailableGB),
                level: diskLevel
            ),
        ]
    }

    private var cpuLevel: HealthLevel {
        if sample.systemCPUPercent > monitor.settings.settings.systemCPUThreshold {
            return .elevated
        }
        return .normal
    }

    private var swapLevel: HealthLevel {
        if sample.swapRatio > monitor.settings.settings.swapRatioThreshold {
            return .elevated
        }
        return .normal
    }

    private var diskLevel: HealthLevel {
        if sample.isDiskLow(thresholdGB: monitor.settings.settings.diskFreeGBThreshold) {
            return .elevated
        }
        return .normal
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }
}
