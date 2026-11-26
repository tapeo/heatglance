import Foundation
import SwiftUI

import HeatGlanceCore

struct ProtectionRowView: View {
    @Environment(Monitor.self) private var monitor

    let showInfo: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("Thermal protection")
                        .font(.callout)
                    Button {
                        showInfo()
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("How thermal protection works")
                    .accessibilityLabel("How thermal protection works")
                }
                Text(protectionStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            pauseControl
            Toggle("Thermal protection", isOn: binding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private var pauseControl: some View {
        if monitor.settings.protection.isEnabled {
            if monitor.settings.protection.isPaused(at: Date()) {
                Button("Resume") { monitor.resumeProtectionNow() }
                    .controlSize(.small)
            } else {
                Menu("Pause") {
                    Button("For 1 hour") {
                        monitor.pauseProtection(until: Date().addingTimeInterval(3600))
                    }
                    Button("Until tomorrow") {
                        let calendar = Calendar.current
                        let tomorrow = calendar.startOfDay(for: Date().addingTimeInterval(86_400))
                        monitor.pauseProtection(until: tomorrow)
                    }
                }
                .menuStyle(.borderlessButton)
                .controlSize(.small)
                .fixedSize()
            }
        }
    }

    private var binding: Binding<Bool> {
        Binding(
            get: { monitor.settings.protection.isEnabled },
            set: { _ in monitor.toggleProtection() }
        )
    }

    private var protectionStatus: String {
        if !monitor.settings.protection.isEnabled {
            return "Off"
        }
        if let until = monitor.settings.protection.pausedUntil, until > Date() {
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        }
        switch monitor.presence {
        case .present:
            return "Standby, you're here"
        case .passive:
            return "Standby, you're here (video or call)"
        case .absent:
            return "Armed, you're away"
        }
    }
}
