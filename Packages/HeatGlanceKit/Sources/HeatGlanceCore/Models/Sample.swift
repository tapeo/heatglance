import Foundation

public struct Sample: Sendable {
    public let date: Date
    public let thermal: ThermalLevel
    public let temperatureCelsius: Double?
    public let memoryPressure: MemoryPressureLevel
    public let swapUsedBytes: UInt64
    public let physicalMemoryBytes: UInt64
    public let systemCPUPercent: Double
    public let diskAvailableBytes: Int64
    public let diskTotalBytes: Int64
    public let groups: [ProcessGroup]

    public init(
        date: Date,
        thermal: ThermalLevel,
        temperatureCelsius: Double?,
        memoryPressure: MemoryPressureLevel,
        swapUsedBytes: UInt64,
        physicalMemoryBytes: UInt64,
        systemCPUPercent: Double,
        diskAvailableBytes: Int64,
        diskTotalBytes: Int64,
        groups: [ProcessGroup]
    ) {
        self.date = date
        self.thermal = thermal
        self.temperatureCelsius = temperatureCelsius
        self.memoryPressure = memoryPressure
        self.swapUsedBytes = swapUsedBytes
        self.physicalMemoryBytes = physicalMemoryBytes
        self.systemCPUPercent = systemCPUPercent
        self.diskAvailableBytes = diskAvailableBytes
        self.diskTotalBytes = diskTotalBytes
        self.groups = groups
    }

    public var swapRatio: Double {
        guard physicalMemoryBytes > 0 else {
            return 0
        }
        return Double(swapUsedBytes) / Double(physicalMemoryBytes)
    }

    public var diskAvailableGB: Double {
        Double(diskAvailableBytes) / Double(1_073_741_824)
    }

    public func isDiskLow(thresholdGB: Double) -> Bool {
        guard diskTotalBytes > 0 else {
            return false
        }
        return diskAvailableGB <= thresholdGB
    }

    public var topGroups: [ProcessGroup] {
        groups.sorted { $0.cpuPercent > $1.cpuPercent }
    }
}
