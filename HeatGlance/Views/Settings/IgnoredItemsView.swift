import SwiftUI

import HeatGlanceCore

struct IgnoredItemsView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if monitor.ignoreList.entries.isEmpty {
                Text("Nothing is ignored. Use the bell button next to a process, or Ignore in a notification.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List {
                    ForEach(monitor.ignoreList.entries) { entry in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(entry.label)
                                if let expiresAt = entry.expiresAt {
                                    Text("Until \(expiresAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Remove") {
                                monitor.removeIgnore(id: entry.id)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, minHeight: 260)
    }
}
