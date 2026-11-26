import SwiftUI

import HeatGlanceCore

struct MetricRowView: View {
    let title: String
    let value: String
    let level: HealthLevel

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(title)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var color: Color {
        switch level {
        case .normal:
            return .green
        case .elevated:
            return .orange
        case .critical:
            return .red
        }
    }
}
