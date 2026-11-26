import AppKit
import Foundation
import SwiftUI

import HeatGlanceCore

struct ProcessRowView: View {
    @Environment(Monitor.self) private var monitor

    let group: ProcessGroup
    let known: KnownItem?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            icon
            nameAndSubtitle
            Spacer(minLength: 8)
            Text(String(format: "%.0f%%", group.cpuPercent))
                .font(.callout.monospacedDigit())
                .foregroundStyle(cpuColor)
                .frame(minWidth: 40, alignment: .trailing)
            actions
        }
        .padding(.vertical, 2)
    }

    private var nameColumn: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(group.displayName)
                .font(.callout)
                .lineLimit(1)
            if let known {
                Text(known.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var nameAndSubtitle: some View {
        if let known {
            nameColumn
                .help(known.explanation)
        } else {
            nameColumn
        }
    }

    private var cpuColor: Color {
        if group.cpuPercent >= monitor.settings.settings.processCPUThreshold {
            return .orange
        }
        return .secondary
    }

    private var actions: some View {
        Menu {
            if !knownSafeToStop {
                Text("Usually better to wait")
                Divider()
            }
            Button("Suspend") { monitor.action(.suspend, on: group) }
            Button("Quit") { monitor.action(.quit, on: group) }
            Divider()
            Button("Ignore for 1 hour") { monitor.ignoreGroup(group) }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Actions")
        .accessibilityLabel("Actions for \(group.displayName)")
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
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "gearshape")
                    .frame(width: 18, height: 18)
            }
        }
    }
}
