import Foundation
import SwiftUI

import HeatGlanceCore

struct LeftoverSectionView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuSectionHeader(title: "Leftover processes")
            ForEach(monitor.leftovers) { candidate in
                HStack(alignment: .center, spacing: 8) {
                    Text(candidate.displayName)
                        .font(.callout)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(String(format: "%.0f%%", candidate.cpuPercent))
                        .font(.callout.monospacedDigit())
                        .foregroundStyle(cpuColor(for: candidate))
                        .frame(minWidth: 40, alignment: .trailing)
                    actions(for: candidate)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func cpuColor(for candidate: OrphanCandidate) -> Color {
        if candidate.cpuPercent >= monitor.settings.settings.processCPUThreshold {
            return .orange
        }
        return .secondary
    }

    private func actions(for candidate: OrphanCandidate) -> some View {
        Menu {
            Button("Quit") {
                if let group = monitor.latest?.groups.first(where: { $0.id == candidate.groupID }) {
                    monitor.action(.quit, on: group)
                }
            }
            Divider()
            Button("Ignore") {
                monitor.ignoreOrphan(candidate.groupID)
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
        .accessibilityLabel("Actions for \(candidate.displayName)")
    }
}
