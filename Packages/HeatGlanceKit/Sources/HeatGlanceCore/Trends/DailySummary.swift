import Foundation

public struct DailySummary: Sendable, Codable, Identifiable {
    public var id: Date { day }
    public let day: Date
    public var thermalSeriousMinutes: Int
    public var protectionInterventions: Int
    public var alerts: Int
    public var topCPU: [AppTotal]
    public var topMemory: [AppTotal]
    public var topWrites: [AppTotal]
    public var cpuAccumulator: [String: Double]
    public var memoryPeaks: [String: Double]
    public var writeAccumulator: [String: Double]

    public init(
        day: Date,
        thermalSeriousMinutes: Int = 0,
        protectionInterventions: Int = 0,
        alerts: Int = 0,
        topCPU: [AppTotal] = [],
        topMemory: [AppTotal] = [],
        topWrites: [AppTotal] = [],
        cpuAccumulator: [String: Double] = [:],
        memoryPeaks: [String: Double] = [:],
        writeAccumulator: [String: Double] = [:]
    ) {
        self.day = day
        self.thermalSeriousMinutes = thermalSeriousMinutes
        self.protectionInterventions = protectionInterventions
        self.alerts = alerts
        self.topCPU = topCPU
        self.topMemory = topMemory
        self.topWrites = topWrites
        self.cpuAccumulator = cpuAccumulator
        self.memoryPeaks = memoryPeaks
        self.writeAccumulator = writeAccumulator
    }
}

public struct AppTotal: Sendable, Codable, Hashable {
    public let groupID: String
    public let displayName: String
    public let value: Double

    public init(groupID: String, displayName: String, value: Double) {
        self.groupID = groupID
        self.displayName = displayName
        self.value = value
    }
}

public struct WeeklyReport: Sendable {
    public struct Entry: Sendable, Identifiable {
        public let groupID: String
        public let displayName: String
        public let value: Double
        public var change: Double?

        public var id: String { "\(groupID)-\(value)" }
    }

    public let topCPU: [Entry]
    public let topMemory: [Entry]
    public let topWrites: [Entry]
    public let seriousMinutes: Int
    public let interventions: Int

    public init(
        topCPU: [Entry],
        topMemory: [Entry],
        topWrites: [Entry],
        seriousMinutes: Int,
        interventions: Int
    ) {
        self.topCPU = topCPU
        self.topMemory = topMemory
        self.topWrites = topWrites
        self.seriousMinutes = seriousMinutes
        self.interventions = interventions
    }
}

public struct DailySummaryStore: Sendable, Codable {
    public var summaries: [DailySummary]
    public let capacity: Int

    public init(summaries: [DailySummary] = [], capacity: Int = 56) {
        self.summaries = summaries
        self.capacity = capacity
    }

    public mutating func ensureDay(_ date: Date) -> DailySummary {
        let day = Calendar.current.startOfDay(for: date)
        if let existing = summaries.first(where: { $0.day == day }) {
            return existing
        }
        let summary = DailySummary(day: day)
        summaries.append(summary)
        trim()
        return summary
    }

    public mutating func update(_ summary: DailySummary) {
        if let index = summaries.firstIndex(where: { $0.day == summary.day }) {
            summaries[index] = summary
        } else {
            summaries.append(summary)
            trim()
        }
    }

    public mutating func trim() {
        summaries.sort { $0.day < $1.day }
        if summaries.count > capacity {
            summaries.removeFirst(summaries.count - capacity)
        }
    }

    public func week(endingAt date: Date) -> WeeklyReport {
        let end = Calendar.current.startOfDay(for: date)
        guard let start = Calendar.current.date(byAdding: .day, value: -6, to: end),
              let previousStart = Calendar.current.date(byAdding: .day, value: -7, to: start)
        else {
            return WeeklyReport(topCPU: [], topMemory: [], topWrites: [], seriousMinutes: 0, interventions: 0)
        }
        let current = summaries.filter { $0.day >= start && $0.day <= end }
        let previous = summaries.filter { $0.day >= previousStart && $0.day < start }

        return WeeklyReport(
            topCPU: aggregate(current, keyPath: \.topCPU, previous: previous.map { summary in
                Dictionary(uniqueKeysWithValues: summary.topCPU.map { ($0.groupID, $0.value) })
            }, combine: { $0 + $1 }),
            topMemory: aggregate(current, keyPath: \.topMemory, previous: previous.map { summary in
                Dictionary(uniqueKeysWithValues: summary.topMemory.map { ($0.groupID, $0.value) })
            }, combine: { max($0, $1) }),
            topWrites: aggregate(current, keyPath: \.topWrites, previous: previous.map { summary in
                Dictionary(uniqueKeysWithValues: summary.topWrites.map { ($0.groupID, $0.value) })
            }, combine: { $0 + $1 }),
            seriousMinutes: current.reduce(0) { $0 + $1.thermalSeriousMinutes },
            interventions: current.reduce(0) { $0 + $1.protectionInterventions }
        )
    }

    private func aggregate(
        _ summaries: [DailySummary],
        keyPath: KeyPath<DailySummary, [AppTotal]>,
        previous: [[String: Double]],
        combine: (Double, Double) -> Double
    ) -> [WeeklyReport.Entry] {
        var totals: [String: (name: String, value: Double)] = [:]
        for summary in summaries {
            for total in summary[keyPath: keyPath] {
                var entry = totals[total.groupID] ?? (total.displayName, 0)
                entry.value = combine(entry.value, total.value)
                totals[total.groupID] = entry
            }
        }
        let previousTotals = previous.reduce(into: [String: Double]()) { result, day in
            for (key, value) in day {
                result[key] = combine(result[key] ?? 0, value)
            }
        }
        return totals
            .map { key, entry in
                var change: Double?
                if let old = previousTotals[key], old > 0 {
                    change = (entry.value - old) / old
                }
                return WeeklyReport.Entry(
                    groupID: key,
                    displayName: entry.name,
                    value: entry.value,
                    change: change
                )
            }
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { $0 }
    }
}
