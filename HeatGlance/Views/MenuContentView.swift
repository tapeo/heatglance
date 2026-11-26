import AppKit
import SwiftUI

struct MenuContentView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MenuStatusHeaderView(perform: perform)
            ProtectionRowView(showInfo: { showWindow(id: "protection-info") })
            Divider()
            if let sample = monitor.latest {
                MetricGridView(sample: sample)
            }
            if !monitor.suspendedGroups.isEmpty {
                SuspendedSectionView()
            }
            if !monitor.leftovers.isEmpty {
                LeftoverSectionView()
            }
            if let sample = monitor.latest {
                ProcessSectionView(sample: sample)
            }
            Divider()
            MenuFooterView(showWindow: { showWindow(id: $0) }, showSettings: showSettings)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 360)
    }

    private func showWindow(id: String) {
        dismiss()
        NSApplication.shared.activate()
        openWindow(id: id)
    }

    private func showSettings() {
        dismiss()
        NSApplication.shared.activate()
        openSettings()
    }

    private func perform(_ action: RuleAction) {
        switch action {
        case .cleanup:
            showWindow(id: "cleanup")
        case let .quit(group):
            monitor.action(.quit, on: group)
        }
    }
}
