import Foundation

public struct TrendsFindings: Sendable {
    public let leaks: [LeakSeries]
    public let writeOffenders: [DiskWriteTracker.AppWrites]
    public let anomalies: [AnomalyFinding]

    public init(leaks: [LeakSeries], writeOffenders: [DiskWriteTracker.AppWrites], anomalies: [AnomalyFinding]) {
        self.leaks = leaks
        self.writeOffenders = writeOffenders
        self.anomalies = anomalies
    }
}

public struct TrendsEngine: Sendable, Codable {
    public var leaks: LeakDetector
    public var writes: DiskWriteTracker
    public var baselines: BaselineStore
    public var summaries: DailySummaryStore
    public var lastNotified: [String: Date]
    public var lastSummarySampleDate: Date?

    public init(
        leaks: LeakDetector = LeakDetector(),
        writes: DiskWriteTracker,
        baselines: BaselineStore = BaselineStore(),
        summaries: DailySummaryStore = DailySummaryStore(),
        lastNotified: [String: Date] = [:],
        lastSummarySampleDate: Date? = nil
    ) {
        self.leaks = leaks
        self.writes = writes
        self.baselines = baselines
        self.summaries = summaries
        self.lastNotified = lastNotified
        self.lastSummarySampleDate = lastSummarySampleDate
    }

    public static func fresh(now: Date) -> TrendsEngine {
        TrendsEngine(writes: DiskWriteTracker(dayStart: Calendar.current.startOfDay(for: now)))
    }

    public mutating func update(sample: Sample, settings: AppSettings) -> TrendsFindings {
        leaks.update(groups: sample.groups, now: sample.date)
        writes.update(groups: sample.groups, now: sample.date)

        var learned: [String: AppBaseline] = [:]
        for group in sample.groups where group.isApplication {
            learned[group.id] = baselines.observe(group: group, now: sample.date)
        }
        let anomalies = AnomalyDetector().findings(
            groups: sample.groups.filter { learned[$0.id] != nil },
            store: baselines,
            now: sample.date,
            cpuMultiplier: settings.anomalyCPUMultiplier,
            cpuFloor: settings.anomalyCPUFloor,
            memoryMultiplier: settings.anomalyMemoryMultiplier,
            memoryFloorBytes: settings.anomalyMemoryFloorBytes
        )

        updateSummary(sample: sample)

        return TrendsFindings(
            leaks: leaks.leaks(now: sample.date),
            writeOffenders: writes.offenders(
                dayGB: settings.diskWriteDailyGB,
                hourGB: settings.diskWriteHourlyGB
            ),
            anomalies: anomalies
        )
    }

    public mutating func shouldNotify(key: String, now: Date, window: TimeInterval = 3600) -> Bool {
        if let last = lastNotified[key], now.timeIntervalSince(last) < window {
            return false
        }
        lastNotified[key] = now
        return true
    }

    private mutating func updateSummary(sample: Sample) {
        let day = Calendar.current.startOfDay(for: sample.date)
        var summary = summaries.ensureDay(day)
        if sample.thermal >= .serious {
            summary.thermalSeriousMinutes += 1
        }
        let interval = takeSummaryInterval(upTo: sample.date)
        for group in sample.groups where group.isApplication {
            if let interval {
                summary.cpuAccumulator[group.id, default: 0] += group.cpuPercent / 100 * interval / 3600
            }
            summary.memoryPeaks[group.id] = max(summary.memoryPeaks[group.id] ?? 0, Double(group.footprintBytes))
        }
        if let top = writes.topWriter {
            summary.writeAccumulator[top.displayName] = max(
                summary.writeAccumulator[top.displayName] ?? 0,
                Double(top.dayBytes) / 1_073_741_824
            )
        }
        summary.topCPU = topTotals(summary.cpuAccumulator, names: nameMap(sample))
        summary.topMemory = topTotals(summary.memoryPeaks, names: nameMap(sample))
        summaries.update(summary)
    }

    private mutating func takeSummaryInterval(upTo date: Date) -> Double? {
        let previous = lastSummarySampleDate
        lastSummarySampleDate = date
        guard let previous else {
            return nil
        }
        let interval = date.timeIntervalSince(previous)
        guard interval > 0, interval <= 120 else {
            return nil
        }
        return interval
    }

    private func nameMap(_ sample: Sample) -> [String: String] {
        Dictionary(uniqueKeysWithValues: sample.groups.map { ($0.id, $0.displayName) })
    }

    private func topTotals(_ values: [String: Double], names: [String: String]) -> [AppTotal] {
        values
            .map { key, value in
                AppTotal(groupID: key, displayName: names[key] ?? key, value: value)
            }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }
}
