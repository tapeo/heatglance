import SwiftUI

import HeatGlanceCore

struct MenuStatusHeaderView: View {
    @Environment(Monitor.self) private var monitor

    let perform: (RuleAction) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: headerIcon.name)
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(headerIcon.color)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.headline)
                subtitle
            }
            Spacer()
        }
    }

    private var headerIcon: (name: String, color: Color) {
        if monitor.latest == nil {
            return ("hourglass", .secondary)
        }
        switch monitor.overall {
        case .critical:
            return ("exclamationmark.triangle.fill", monitor.overall.color)
        case .elevated:
            return ("thermometer.medium", monitor.overall.color)
        case .normal:
            return ("thermometer.medium", monitor.overall.color)
        }
    }

    private var heading: String {
        if monitor.latest == nil {
            return "Starting up"
        }
        switch monitor.overall {
        case .normal:
            return "Everything looks normal"
        case .elevated:
            return "Something needs attention"
        case .critical:
            return "Under pressure"
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if monitor.latest == nil {
            Text("Waiting for the first sample…")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if monitor.activeRules.isEmpty {
            Text("No active warnings")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            AttentionView(rules: monitor.activeRules, sample: monitor.latest, perform: perform)
        }
    }
}
