import Foundation

import HeatGlanceCore

enum RuleAction: Equatable {
    case cleanup
    case quit(ProcessGroup)
}

struct RuleSummary {
    let title: String
    let detail: String?
    let action: RuleAction?

    static func make(for rule: ActiveRule, sample: Sample?) -> RuleSummary {
        guard let sample else {
            return RuleSummary(title: rule.title, detail: nil, action: nil)
        }
        switch rule.ruleID {
        case "disk_free":
            return RuleSummary(title: rule.title, detail: String(format: "%.1f GB free", sample.diskAvailableGB), action: .cleanup)
        case "thermal_serious", "thermal_critical":
            return RuleSummary(title: rule.title, detail: thermalText(sample), action: nil)
        case "memory_warning", "memory_critical":
            return RuleSummary(title: rule.title, detail: memoryDetail(sample), action: nil)
        case "swap_high":
            return RuleSummary(title: rule.title, detail: "\(bytes(sample.swapUsedBytes)) of swap in use", action: nil)
        case "system_cpu":
            return RuleSummary(title: rule.title, detail: String(format: "CPU at %.0f%%", sample.systemCPUPercent), action: nil)
        default:
            return groupSummary(for: rule, sample: sample)
        }
    }

    static func thermalText(_ sample: Sample) -> String {
        if let temperature = sample.temperatureCelsius {
            return "\(sample.thermal.title), \(Int(temperature)) °C"
        }
        return sample.thermal.title
    }

    private static func groupSummary(for rule: ActiveRule, sample: Sample) -> RuleSummary {
        guard let groupID = rule.groupID, let group = sample.groups.first(where: { $0.id == groupID }) else {
            return RuleSummary(title: rule.title, detail: nil, action: nil)
        }
        let detail: String?
        if rule.ruleID == "process_cpu" {
            detail = String(format: "%.0f%% CPU", group.cpuPercent)
        } else {
            detail = nil
        }
        return RuleSummary(
            title: "\(group.displayName): \(lowercasedFirst(rule.title))",
            detail: detail,
            action: .quit(group)
        )
    }

    private static func memoryDetail(_ sample: Sample) -> String {
        if let group = sample.groups.max(by: { $0.footprintBytes < $1.footprintBytes }) {
            return "\(group.displayName) uses \(bytes(group.footprintBytes))"
        }
        return "Pressure: \(sample.memoryPressure.title)"
    }

    private static func bytes(_ value: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(value), countStyle: .memory)
    }

    private static func lowercasedFirst(_ text: String) -> String {
        guard let first = text.first else {
            return text
        }
        return first.lowercased() + text.dropFirst()
    }
}
