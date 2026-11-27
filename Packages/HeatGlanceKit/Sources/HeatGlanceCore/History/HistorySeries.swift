import Foundation

public enum HistoryRange: String, CaseIterable, Identifiable, Sendable {
    case sixHours
    case day
    case week

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .sixHours:
            return "6 hours"
        case .day:
            return "24 hours"
        case .week:
            return "7 days"
        }
    }

    public var duration: TimeInterval {
        switch self {
        case .sixHours:
            return 6 * 3600
        case .day:
            return 24 * 3600
        case .week:
            return 7 * 86_400
        }
    }

    public var bucketSeconds: TimeInterval {
        switch self {
        case .sixHours:
            return 60
        case .day:
            return 300
        case .week:
            return 1800
        }
    }
}

public enum HistoryWindow: Hashable, Sendable {
    case recent(HistoryRange)
    case day(Date)

    public func interval(now: Date, calendar: Calendar = .current) -> DateInterval {
        switch self {
        case let .recent(range):
            return DateInterval(start: now.addingTimeInterval(-range.duration), end: now)
        case let .day(date):
            if let interval = calendar.dateInterval(of: .day, for: date) {
                return interval
            }
            let start = calendar.startOfDay(for: date)
            return DateInterval(start: start, duration: 86_400)
        }
    }

    public var bucketSeconds: TimeInterval {
        switch self {
        case let .recent(range):
            return range.bucketSeconds
        case .day:
            return 60
        }
    }

    public func dayStart(calendar: Calendar = .current) -> Date? {
        guard case let .day(date) = self else {
            return nil
        }
        return calendar.startOfDay(for: date)
    }

    public static func availableDays(now: Date, calendar: Calendar = .current) -> [Date] {
        let today = calendar.startOfDay(for: now)
        var days: [Date] = []
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                continue
            }
            days.append(day)
        }
        return days
    }
}

public struct HistoryBucket: Sendable, Identifiable, Equatable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public let segment: Int
    public let thermal: ThermalLevel
    public let memoryPressure: MemoryPressureLevel
    public let systemCPUPercent: Double
    public let temperatureCelsius: Double?
    public let swapUsedBytes: UInt64
    public let diskAvailableBytes: Int64
    public let worstGroupName: String?
    public let worstGroupCPU: Double
    public let isAway: Bool
    public let pausedApps: Int

    public init(
        start: Date,
        end: Date,
        segment: Int,
        thermal: ThermalLevel,
        memoryPressure: MemoryPressureLevel,
        systemCPUPercent: Double,
        temperatureCelsius: Double?,
        swapUsedBytes: UInt64,
        diskAvailableBytes: Int64,
        worstGroupName: String?,
        worstGroupCPU: Double,
        isAway: Bool,
        pausedApps: Int
    ) {
        self.start = start
        self.end = end
        self.segment = segment
        self.thermal = thermal
        self.memoryPressure = memoryPressure
        self.systemCPUPercent = systemCPUPercent
        self.temperatureCelsius = temperatureCelsius
        self.swapUsedBytes = swapUsedBytes
        self.diskAvailableBytes = diskAvailableBytes
        self.worstGroupName = worstGroupName
        self.worstGroupCPU = worstGroupCPU
        self.isAway = isAway
        self.pausedApps = pausedApps
    }
}

public enum HistorySeries {
    public static func buckets(
        points: [HistoryPoint],
        window: HistoryWindow,
        now: Date,
        calendar: Calendar = .current
    ) -> [HistoryBucket] {
        let interval = window.interval(now: now, calendar: calendar)
        let bucketSeconds = window.bucketSeconds
        let selected = points.filter { interval.contains($0.minute) }
        let grouped = Dictionary(grouping: selected) { start in
            bucketStart(for: start.minute, bucketSeconds: bucketSeconds)
        }

        var buckets: [HistoryBucket] = []
        var segment = 0
        var previousStart: Date?

        for start in grouped.keys.sorted() {
            if let previousStart, start.timeIntervalSince(previousStart) > 2 * bucketSeconds {
                segment += 1
            }
            guard let group = grouped[start] else {
                continue
            }
            let end = start.addingTimeInterval(bucketSeconds)
            buckets.append(makeBucket(start: start, end: end, points: group, segment: segment))
            previousStart = start
        }

        return buckets
    }

    public static func spans(_ buckets: [HistoryBucket], where predicate: (HistoryBucket) -> Bool) -> [DateInterval] {
        var result: [DateInterval] = []
        var start: Date?
        var end: Date?
        var segment: Int?

        func flush() {
            if let start, let end {
                result.append(DateInterval(start: start, end: end))
            }
            start = nil
            end = nil
            segment = nil
        }

        for bucket in buckets {
            guard predicate(bucket) else {
                flush()
                continue
            }
            if let currentEnd = end, segment == bucket.segment {
                end = max(currentEnd, bucket.end)
                continue
            }
            flush()
            start = bucket.start
            end = bucket.end
            segment = bucket.segment
        }
        flush()

        return result
    }

    public static func bucket(at date: Date, in buckets: [HistoryBucket]) -> HistoryBucket? {
        buckets.first { $0.start <= date && date < $0.end }
    }

    private static func bucketStart(for date: Date, bucketSeconds: TimeInterval) -> Date {
        let interval = date.timeIntervalSince1970
        return Date(timeIntervalSince1970: (interval / bucketSeconds).rounded(.down) * bucketSeconds)
    }

    private static func makeBucket(start: Date, end: Date, points: [HistoryPoint], segment: Int) -> HistoryBucket {
        let thermal = points.map(\.thermal).max() ?? .nominal
        let memoryPressure = points.map(\.memoryPressure).max() ?? .normal
        let systemCPUPercent = points.map(\.systemCPUPercent).max() ?? 0
        let temperatureCelsius = points.compactMap(\.temperatureCelsius).max()
        let swapUsedBytes = points.map(\.swapUsedBytes).max() ?? 0
        let diskAvailableBytes = points.map(\.diskAvailableBytes).min() ?? 0
        let worst = points.max { $0.worstGroupCPU < $1.worstGroupCPU }
        let isAway = points.contains { $0.isAway == true }
        let pausedApps = points.compactMap(\.pausedApps).max() ?? 0

        return HistoryBucket(
            start: start,
            end: end,
            segment: segment,
            thermal: thermal,
            memoryPressure: memoryPressure,
            systemCPUPercent: systemCPUPercent,
            temperatureCelsius: temperatureCelsius,
            swapUsedBytes: swapUsedBytes,
            diskAvailableBytes: diskAvailableBytes,
            worstGroupName: worst?.worstGroupName,
            worstGroupCPU: worst?.worstGroupCPU ?? 0,
            isAway: isAway,
            pausedApps: pausedApps
        )
    }
}
