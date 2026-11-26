import AppKit
import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct MenuContentView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusHeader
            protectionRow
            Divider()
            metrics
            if !monitor.suspendedGroups.isEmpty {
                Divider()
                suspendedSection
            }
            Divider()
            processSection
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 330)
    }

    private var statusHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: monitor.overall == .critical ? "exclamationmark.triangle.fill" : "thermometer.medium")
                .foregroundStyle(color(for: monitor.overall))
            VStack(alignment: .leading, spacing: 2) {
                Text(title(for: monitor.overall))
                    .font(.headline)
                if let active = activeRuleTitle {
                    Text(active)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }

    private var protectionRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Toggle("Thermal protection", isOn: Binding(
                    get: { monitor.settings.protection.isEnabled },
                    set: { _ in monitor.toggleProtection() }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                Spacer()
                if monitor.settings.protection.isPaused(at: Date()) {
                    Button("Resume now") { monitor.resumeProtectionNow() }
                        .controlSize(.mini)
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
                    .controlSize(.mini)
                    .fixedSize()
                }
            }
            Text(protectionStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let sample = monitor.latest {
                MetricRowView(
                    title: "Thermal",
                    value: thermalText(sample),
                    level: sample.thermal.healthLevel
                )
                MetricRowView(
                    title: "Memory pressure",
                    value: sample.memoryPressure.title,
                    level: sample.memoryPressure.healthLevel
                )
                MetricRowView(
                    title: "Swap",
                    value: bytes(sample.swapUsedBytes),
                    level: sample.swapRatio > monitor.settings.settings.swapRatioThreshold ? .elevated : .normal
                )
                MetricRowView(
                    title: "CPU",
                    value: String(format: "%.0f%%", sample.systemCPUPercent),
                    level: sample.systemCPUPercent > monitor.settings.settings.systemCPUThreshold ? .elevated : .normal
                )
                MetricRowView(
                    title: "Disk free",
                    value: String(format: "%.1f GB", sample.diskAvailableGB),
                    level: sample.diskAvailableGB < monitor.settings.settings.diskFreeGBThreshold ? .elevated : .normal
                )
            } else {
                Text("Waiting for the first sample…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var suspendedSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Paused by protection")
                    .font(.caption.bold())
                Spacer()
                Button("Resume all") { monitor.resumeAllSuspended() }
                    .controlSize(.mini)
            }
            ForEach(monitor.suspendedGroups, id: \.groupID) { group in
                HStack {
                    Text(group.displayName)
                        .font(.caption)
                    Spacer()
                    Button("Resume") {
                        monitor.resume(groupID: group.groupID)
                    }
                    .controlSize(.mini)
                }
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top processes")
                .font(.caption.bold())
            let groups = Array((monitor.latest?.topGroups ?? []).prefix(4))
            if groups.isEmpty {
                Text("Nothing to show")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.id) { group in
                ProcessRowView(group: group, known: knownItem(for: group))
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                monitor.sleepDisplay()
            } label: {
                Label("Sleep display", systemImage: "moon.zzz")
            }
            .controlSize(.small)
            Spacer()
            Button("Cleanup") { openWindow(id: "cleanup") }
                .controlSize(.small)
            Button("History") { openWindow(id: "history") }
                .controlSize(.small)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .controlSize(.small)
        }
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

    private var activeRuleTitle: String? {
        monitor.ruleState.firingSince.keys.first
    }

    private func knownItem(for group: ProcessGroup) -> KnownItem? {
        KnowledgeBase.shared.match(
            groupID: group.id,
            processName: group.members.first?.name,
            executablePath: group.members.first?.executablePath
        )
    }

    private func thermalText(_ sample: Sample) -> String {
        if let temperature = sample.temperatureCelsius {
            return "\(sample.thermal.title), \(Int(temperature)) °C"
        }
        return sample.thermal.title
    }

    private func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    private func title(for level: HealthLevel) -> String {
        switch level {
        case .normal:
            return "Everything looks normal"
        case .elevated:
            return "Something needs attention"
        case .critical:
            return "Under pressure"
        }
    }

    private func color(for level: HealthLevel) -> Color {
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
