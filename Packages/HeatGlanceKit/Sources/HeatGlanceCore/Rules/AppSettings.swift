import Foundation

public struct AppSettings: Sendable, Codable, Equatable {
    public var thermalSustainSeconds: Double
    public var memoryWarningSustainSeconds: Double
    public var memoryClearSeconds: Double
    public var swapRatioThreshold: Double
    public var swapSustainSeconds: Double
    public var systemCPUThreshold: Double
    public var systemCPUSustainSeconds: Double
    public var processCPUThreshold: Double
    public var processCPUSustainSeconds: Double
    public var diskFreeRatioThreshold: Double
    public var diskFreeGBThreshold: Double
    public var uptimeDays: Int
    public var leakMinimumBytes: UInt64
    public var diskWriteDailyGB: Double
    public var diskWriteHourlyGB: Double
    public var anomalyCPUMultiplier: Double
    public var anomalyCPUFloor: Double
    public var anomalyMemoryMultiplier: Double
    public var anomalyMemoryFloorBytes: UInt64
    public var cooldownSeconds: Double

    public init(
        thermalSustainSeconds: Double = 60,
        memoryWarningSustainSeconds: Double = 30,
        memoryClearSeconds: Double = 30,
        swapRatioThreshold: Double = 0.25,
        swapSustainSeconds: Double = 300,
        systemCPUThreshold: Double = 90,
        systemCPUSustainSeconds: Double = 120,
        processCPUThreshold: Double = 150,
        processCPUSustainSeconds: Double = 120,
        diskFreeRatioThreshold: Double = 0.10,
        diskFreeGBThreshold: Double = 20,
        uptimeDays: Int = 21,
        leakMinimumBytes: UInt64 = 1_073_741_824,
        diskWriteDailyGB: Double = 50,
        diskWriteHourlyGB: Double = 10,
        anomalyCPUMultiplier: Double = 5,
        anomalyCPUFloor: Double = 30,
        anomalyMemoryMultiplier: Double = 3,
        anomalyMemoryFloorBytes: UInt64 = 1_073_741_824,
        cooldownSeconds: Double = 900
    ) {
        self.thermalSustainSeconds = thermalSustainSeconds
        self.memoryWarningSustainSeconds = memoryWarningSustainSeconds
        self.memoryClearSeconds = memoryClearSeconds
        self.swapRatioThreshold = swapRatioThreshold
        self.swapSustainSeconds = swapSustainSeconds
        self.systemCPUThreshold = systemCPUThreshold
        self.systemCPUSustainSeconds = systemCPUSustainSeconds
        self.processCPUThreshold = processCPUThreshold
        self.processCPUSustainSeconds = processCPUSustainSeconds
        self.diskFreeRatioThreshold = diskFreeRatioThreshold
        self.diskFreeGBThreshold = diskFreeGBThreshold
        self.uptimeDays = uptimeDays
        self.leakMinimumBytes = leakMinimumBytes
        self.diskWriteDailyGB = diskWriteDailyGB
        self.diskWriteHourlyGB = diskWriteHourlyGB
        self.anomalyCPUMultiplier = anomalyCPUMultiplier
        self.anomalyCPUFloor = anomalyCPUFloor
        self.anomalyMemoryMultiplier = anomalyMemoryMultiplier
        self.anomalyMemoryFloorBytes = anomalyMemoryFloorBytes
        self.cooldownSeconds = cooldownSeconds
    }

    public static let defaults = AppSettings()
}
