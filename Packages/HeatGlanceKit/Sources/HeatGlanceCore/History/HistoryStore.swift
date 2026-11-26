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

    public init(
        minute: Date,
        thermal: ThermalLevel,
        memoryPressure: MemoryPressureLevel,
        systemCPUPercent: Double,
        swapUsedBytes: UInt64,
        diskAvailableBytes: Int64,
        worstGroupName: String?,
        worstGroupCPU: Double
    ) {
        self.minute = minute
        self.thermal = thermal
        self.memoryPressure = memoryPressure
        self.systemCPUPercent = systemCPUPercent
        self.swapUsedBytes = swapUsedBytes
        self.diskAvailableBytes = diskAvailableBytes
        self.worstGroupName = worstGroupName
        self.worstGroupCPU = worstGroupCPU
    }

    public static func minute(of date: Date) -> Date {
        let interval = 60.0
        return Date(timeIntervalSince1970: (date.timeIntervalSince1970 / interval).rounded(.down) * interval)
    }
}

public struct HistoryStore: Sendable, Codable {
    public static let capacity = 1440

    public private(set) var points: [HistoryPoint]
    public private(set) var lastSavedAt: Date?

    public init(points: [HistoryPoint] = [], lastSavedAt: Date? = nil) {
        self.points = points
        self.lastSavedAt = lastSavedAt
    }

    public mutating func record(_ sample: Sample) {
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
            worstGroupCPU: worst?.cpuPercent ?? 0
        )
        if let index = points.lastIndex(where: { $0.minute == minute }) {
            points[index] = point
        } else {
            points.append(point)
        }
        if points.count > Self.capacity {
            points.removeFirst(points.count - Self.capacity)
        }
        trim(olderThan: sample.date.addingTimeInterval(-86_400))
    }

    public mutating func trim(olderThan cutoff: Date) {
        points.removeAll { $0.minute < cutoff }
    }

    public func points(since date: Date) -> [HistoryPoint] {
        points.filter { $0.minute >= date }
    }
}
