import Foundation

public struct HistoryPoint: Sendable, Codable, Identifiable {
    public var id: Date { minute }
    public let minute: Date
    public let thermal: ThermalLevel
    public let memoryPressure: MemoryPressureLevel
    public let systemCPUPercent: Double
    public let swapUsedBytes: UInt64
    public let diskAvailableBytes: Int64
    public let worstGroupName: String?
    public let worstGroupCPU: Double
    public let temperatureCelsius: Double?
    public let isAway: Bool?
    public let pausedApps: Int?

    public init(
        minute: Date,
        thermal: ThermalLevel,
        memoryPressure: MemoryPressureLevel,
        systemCPUPercent: Double,
        swapUsedBytes: UInt64,
        diskAvailableBytes: Int64,
        worstGroupName: String?,
        worstGroupCPU: Double,
        temperatureCelsius: Double? = nil,
        isAway: Bool? = nil,
        pausedApps: Int? = nil
    ) {
        self.minute = minute
        self.thermal = thermal
        self.memoryPressure = memoryPressure
        self.systemCPUPercent = systemCPUPercent
        self.swapUsedBytes = swapUsedBytes
        self.diskAvailableBytes = diskAvailableBytes
        self.worstGroupName = worstGroupName
        self.worstGroupCPU = worstGroupCPU
        self.temperatureCelsius = temperatureCelsius
        self.isAway = isAway
        self.pausedApps = pausedApps
    }

    public static func minute(of date: Date) -> Date {
        let interval = 60.0
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / interval).rounded(.down) * interval)
    }
}

public struct HistoryStore: Sendable, Codable {
    public static let capacity = 10_080
    public static let retention: TimeInterval = 7 * 86_400

    public private(set) var points: [HistoryPoint]
    public private(set) var lastSavedAt: Date?

    public init(points: [HistoryPoint] = [], lastSavedAt: Date? = nil) {
        self.points = points
        self.lastSavedAt = lastSavedAt
    }

    public mutating func record(_ sample: Sample, isAway: Bool = false, pausedApps: Int = 0) {
        let minute = HistoryPoint.minute(of: sample.date)
        let worst = sample.topGroups.first
        let point = HistoryPoint(
            minute: minute,
            thermal: sample.thermal,
            memoryPressure: sample.memoryPressure,
            systemCPUPercent: sample.systemCPUPercent,
            swapUsedBytes: sample.swapUsedBytes,
            diskAvailableBytes: sample.diskAvailableBytes,
            worstGroupName: worst?.displayName,
            worstGroupCPU: worst?.cpuPercent ?? 0,
            temperatureCelsius: sample.temperatureCelsius,
            isAway: isAway,
            pausedApps: pausedApps
        )
        if let index = points.lastIndex(where: { $0.minute == minute }) {
            points[index] = point
        } else {
            points.append(point)
        }
        if points.count > Self.capacity {
            points.removeFirst(points.count - Self.capacity)
        }
        trim(olderThan: sample.date.addingTimeInterval(-Self.retention))
    }

    public mutating func trim(olderThan cutoff: Date) {
        guard let first = points.first else {
            return
        }
        guard first.minute < cutoff else {
            return
        }
        points.removeAll { $0.minute < cutoff }
    }

    public func points(since date: Date) -> [HistoryPoint] {
        points.filter { $0.minute >= date }
    }
}
