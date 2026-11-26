import Foundation

public struct RuleCatalog {
    public init() {}

    public var rules: [RuleDefinition] {
        [
            thermalSerious,
            thermalCritical,
            memoryWarning,
            memoryCritical,
            swap,
            systemCPU,
            processCPU,
            diskFree,
            uptime,
            leak,
            diskWrite,
            anomalyCPU,
            anomalyMemory,
        ]
    }

    public var thermalSerious: RuleDefinition {
        RuleDefinition(
            id: "thermal_serious",
            title: "Mac is getting hot",
            level: .elevated,
            scope: .system,
            sustainSeconds: 60,
            clearSeconds: 0
        ) { sample, settings in
            sample.thermal >= .serious && sample.thermal < .critical
        }
    }

    public var thermalCritical: RuleDefinition {
        RuleDefinition(
            id: "thermal_critical",
            title: "Mac is critically hot",
            level: .critical,
            scope: .system,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { sample, _ in
            sample.thermal == .critical
        }
    }

    public var memoryWarning: RuleDefinition {
        RuleDefinition(
            id: "memory_warning",
            title: "Memory pressure is high",
            level: .elevated,
            scope: .system,
            sustainSeconds: 30,
            clearSeconds: 30
        ) { sample, settings in
            sample.memoryPressure == .warning
        }
    }

    public var memoryCritical: RuleDefinition {
        RuleDefinition(
            id: "memory_critical",
            title: "Memory pressure is critical",
            level: .critical,
            scope: .system,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { sample, _ in
            sample.memoryPressure == .critical
        }
    }

    public var swap: RuleDefinition {
        RuleDefinition(
            id: "swap_high",
            title: "Swap is growing",
            level: .elevated,
            scope: .system,
            sustainSeconds: 300,
            clearSeconds: 0
        ) { sample, settings in
            sample.swapRatio >= settings.swapRatioThreshold
        }
    }

    public var systemCPU: RuleDefinition {
        RuleDefinition(
            id: "system_cpu",
            title: "CPU is pegged",
            level: .elevated,
            scope: .system,
            sustainSeconds: 120,
            clearSeconds: 0
        ) { sample, settings in
            sample.systemCPUPercent >= settings.systemCPUThreshold
        }
    }

    public var processCPU: RuleDefinition {
        RuleDefinition(
            id: "process_cpu",
            title: "Using a lot of CPU",
            level: .elevated,
            scope: .applications,
            sustainSeconds: 120,
            clearSeconds: 0
        ) { sample, settings in
            sample.groups.contains { $0.cpuPercent >= settings.processCPUThreshold }
        }
    }

    public var diskFree: RuleDefinition {
        RuleDefinition(
            id: "disk_free",
            title: "Disk is almost full",
            level: .elevated,
            scope: .system,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { sample, settings in
            sample.isDiskLow(thresholdGB: settings.diskFreeGBThreshold)
        }
    }

    public var uptime: RuleDefinition {
        RuleDefinition(
            id: "uptime",
            title: "No restart in a long time",
            level: .elevated,
            scope: .system,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { _, _ in
            false
        }
    }

    public var leak: RuleDefinition {
        RuleDefinition(
            id: "memory_leak",
            title: "Memory keeps growing",
            level: .elevated,
            scope: .applications,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { _, _ in
            false
        }
    }

    public var diskWrite: RuleDefinition {
        RuleDefinition(
            id: "disk_write",
            title: "Writing a lot to disk",
            level: .elevated,
            scope: .applications,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { _, _ in
            false
        }
    }

    public var anomalyCPU: RuleDefinition {
        RuleDefinition(
            id: "anomaly_cpu",
            title: "Using much more CPU than usual",
            level: .elevated,
            scope: .applications,
            sustainSeconds: 300,
            clearSeconds: 0
        ) { _, _ in
            false
        }
    }

    public var anomalyMemory: RuleDefinition {
        RuleDefinition(
            id: "anomaly_memory",
            title: "Using much more memory than usual",
            level: .elevated,
            scope: .applications,
            sustainSeconds: 0,
            clearSeconds: 0
        ) { _, _ in
            false
        }
    }

    public func definition(id: String) -> RuleDefinition? {
        rules.first { $0.id == id }
    }
}
