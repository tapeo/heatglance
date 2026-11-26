import AppKit
import SwiftUI

import HeatGlanceCore

struct ProcessRowView: View {
    @Environment(Monitor.self) private var monitor

    let group: ProcessGroup
    let known: KnownItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                icon
                VStack(alignment: .leading, spacing: 1) {
                    Text(group.displayName)
                        .font(.caption)
                        .lineLimit(1)
                    if let known {
                        Text(known.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(String(format: "%.0f%%", group.cpuPercent))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let known {
                Text(known.explanation)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Button("Suspend") { monitor.action(.suspend, on: group) }
                Button("Quit") { monitor.action(.quit, on: group) }
                if !knownSafeToStop {
                    Text("Usually better to wait")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    _ = monitor.ignoreGroup(group)
                } label: {
                    Image(systemName: "bell.slash")
                }
                .help("Ignore for 1 hour")
            }
            .controlSize(.mini)
            .buttonStyle(.link)
        }
        .padding(.vertical, 2)
    }

    private var knownSafeToStop: Bool {
        guard let known else {
            return true
        }
        return known.safeToStop
    }

    private var icon: some View {
        Group {
            if let app = NSRunningApplication(processIdentifier: group.members.first?.identity.pid ?? 0),
               let image = app.icon {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "gearshape")
                    .frame(width: 16, height: 16)
            }
        }
    }
}
