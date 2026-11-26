import SwiftUI

import HeatGlanceCore

struct AttentionView: View {
    let rules: [ActiveRule]
    let sample: Sample?
    let perform: (RuleAction) -> Void

    var body: some View {
        if let first = rules.first {
            let summary = RuleSummary.make(for: first, sample: sample)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(summary.title)
                            .font(.caption.bold())
                            .lineLimit(1)
                        if let detail = summary.detail {
                            Text(detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 4)
                    if let action = summary.action {
                        Button(actionTitle(action)) {
                            perform(action)
                        }
                        .controlSize(.mini)
                    }
                }
                if rules.count > 1 {
                    Text("+\(rules.count - 1) more")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .help(otherTitles)
                }
            }
        }
    }

    private func actionTitle(_ action: RuleAction) -> String {
        switch action {
        case .cleanup:
            return "Clean up"
        case .quit:
            return "Quit"
        }
    }

    private var otherTitles: String {
        let titles = rules.dropFirst().map { rule in
            RuleSummary.make(for: rule, sample: sample).title
        }
        return titles.joined(separator: "\n")
    }
}
