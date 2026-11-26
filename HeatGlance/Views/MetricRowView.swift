import SwiftUI

import HeatGlanceCore

struct MetricRowView: View {
    let title: String
    let value: String
    let level: HealthLevel

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(level.color)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .layoutPriority(1)
        }
    }
}
