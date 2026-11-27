import Foundation

public enum HistoryEventValue {
    public static func alert(ruleID: String, groupID: String?, sample: Sample) -> (appName: String?, value: String?) {
        if let groupID {
            let group = sample.groups.first { $0.id == groupID }
            return (group?.displayName, groupAlertValue(ruleID: ruleID, group: group))
        }
        return (culprit(ruleID: ruleID, sample: sample), systemValue(ruleID: ruleID, sample: sample))
    }

    public static func group(_ group: ProcessGroup) -> String {
        "CPU \(percent(group.cpuPercent)), memory \(gigabytes(Double(group.footprintBytes))) GB"
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "under 1 min"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let rest = minutes % 60
        if rest == 0 {
            return "\(hours) h"
        }
        return "\(hours) h \(rest) min"
    }

    private static func groupAlertValue(ruleID: String, group: ProcessGroup?) -> String? {
        guard let group else {
            return nil
        }
        switch ruleID {
        case "process_cpu", "anomaly_cpu":
            return "CPU \(percent(group.cpuPercent))"
        case "memory_leak", "anomaly_memory":
            return "Memory \(gigabytes(Double(group.footprintBytes))) GB"
        default:
            return nil
        }
    }

    private static func systemValue(ruleID: String, sample: Sample) -> String? {
        switch ruleID {
        case "thermal_serious", "thermal_critical":
            let level = "Thermal \(sample.thermal.title.lowercased())"
            guard let temperature = sample.temperatureCelsius else {
                return level
            }
            return "\(level), \(String(format: "%.0f °C", temperature))"
        case "memory_warning", "memory_critical":
            return "Memory pressure \(sample.memoryPressure.title.lowercased())"
        case "swap_high":
            return "Swap \(gigabytes(Double(sample.swapUsedBytes))) GB"
        case "system_cpu":
            return "CPU \(percent(sample.systemCPUPercent))"
        case "disk_free":
            return "Free disk \(gigabytes(Double(sample.diskAvailableBytes))) GB"
        default:
            return nil
        }
    }

    private static func culprit(ruleID: String, sample: Sample) -> String? {
        switch ruleID {
        case "thermal_serious", "thermal_critical", "system_cpu":
            return sample.topGroups.first?.displayName
        case "memory_warning", "memory_critical", "swap_high":
            return sample.groups.max { $0.footprintBytes < $1.footprintBytes }?.displayName
        default:
            return nil
        }
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private static func gigabytes(_ bytes: Double) -> String {
        String(format: "%.1f", bytes / 1_073_741_824)
    }
}
