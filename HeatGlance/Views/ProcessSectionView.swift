import SwiftUI

import HeatGlanceCore

struct ProcessSectionView: View {
    @Environment(Monitor.self) private var monitor

    let sample: Sample

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MenuSectionHeader(title: "Top processes by CPU")
            let groups = Array(sample.topGroups.prefix(4))
            if groups.isEmpty {
                Text("No processes to show")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups, id: \.id) { group in
                    ProcessRowView(group: group, known: monitor.knownItem(for: group))
                }
            }
        }
    }
}
