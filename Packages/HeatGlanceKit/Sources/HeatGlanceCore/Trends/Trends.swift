import Foundation

public struct LeakSeries: Sendable, Codable, Hashable {
    public var samples: [TrendPoint]
    public let groupID: String
    public let displayName: String

    public init(groupID: String, displayName: String, samples: [TrendPoint] = []) {
        self.groupID = groupID
        self.displayName = displayName
        self.samples = samples
    }
}

public struct TrendPoint: Sendable, Codable, Hashable {
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.date = date
        self.value = value
    }
}

public struct LeakDetector: Sendable, Codable {
    public struct Settings: Sendable {
        public var minimumFootprintBytes: UInt64
        public var minimumGrowthBytes: UInt64
        public var minimumGrowthRatio: Double
        public var window: TimeInterval
        public var pointInterval: TimeInterval

        public init(
            minimumFootprintBytes: UInt64 = 500 * 1_048_576,
            minimumGrowthBytes: UInt64 = 1_073_741_824,
            minimumGrowthRatio: Double = 0.5,
            window: TimeInterval = 3 * 3600,
            pointInterval: TimeInterval = 300
        ) {
            self.minimumFootprintBytes = minimumFootprintBytes
            self.minimumGrowthBytes = minimumGrowthBytes
            self.minimumGrowthRatio = minimumGrowthRatio
            self.window = window
            self.pointInterval = pointInterval
        }

        public static let defaults = Settings()
    }

    public var series: [String: LeakSeries]

    public init() {
        series = [:]
    }

    public mutating func update(groups: [ProcessGroup], now: Date, settings: Settings = .defaults) {
        for group in groups where group.isApplication {
            guard group.footprintBytes >= settings.minimumFootprintBytes else {
                series.removeValue(forKey: group.id)
                continue
            }
            var entry = series[group.id] ?? LeakSeries(groupID: group.id, displayName: group.displayName)
            let value = Double(group.footprintBytes)
            if let last = entry.samples.last, now.timeIntervalSince(last.date) < settings.pointInterval {
                entry.samples[entry.samples.count - 1] = TrendPoint(date: last.date, value: value)
            } else {
                entry.samples.append(TrendPoint(date: now, value: value))
            }
            entry.samples.removeAll { now.timeIntervalSince($0.date) > settings.window }
            series[group.id] = entry
        }
        let alive = Set(groups.map(\.id))
        series = series.filter { alive.contains($0.key) }
    }

    public func leaks(now: Date, settings: Settings = .defaults) -> [LeakSeries] {
        series.values.filter { entry in
            guard let first = entry.samples.first, let last = entry.samples.last, entry.samples.count >= 4 else {
                return false
            }
            guard now.timeIntervalSince(first.date) >= settings.window * 0.8 else {
                return false
            }
            let growth = last.value - first.value
            guard growth >= Double(settings.minimumGrowthBytes) else {
                return false
            }
            guard first.value > 0, growth / first.value >= settings.minimumGrowthRatio else {
                return false
            }
            var rising = 0
            for (previous, next) in zip(entry.samples, entry.samples.dropFirst()) {
                if next.value >= previous.value * 0.995 {
                    rising += 1
                }
            }
            let ratio = Double(rising) / Double(max(entry.samples.count - 1, 1))
            return ratio >= 0.8
        }
    }

    public func series(for groupID: String) -> LeakSeries? {
        series[groupID]
    }
}

public struct DiskWriteTracker: Sendable, Codable {
    public struct AppWrites: Sendable, Codable {
        public var displayName: String
        public var dayBytes: UInt64
        public var hourStart: Date
        public var hourBytes: UInt64
        public var lastCumulative: UInt64
    }

    public var dayStart: Date
    public var apps: [String: AppWrites]

    public init(dayStart: Date, apps: [String: AppWrites] = [:]) {
        self.dayStart = dayStart
        self.apps = apps
    }

    public mutating func update(groups: [ProcessGroup], now: Date) {
        let startOfDay = Calendar.current.startOfDay(for: now)
        if startOfDay != dayStart {
            dayStart = startOfDay
            apps = [:]
        }
        for group in groups {
            let cumulative = group.bytesWritten
            var entry = apps[group.id] ?? AppWrites(
                displayName: group.displayName,
                dayBytes: 0,
                hourStart: now,
                hourBytes: 0,
                lastCumulative: cumulative
            )
            let delta: UInt64
            if cumulative >= entry.lastCumulative {
                delta = cumulative - entry.lastCumulative
            } else {
                delta = cumulative
            }
            entry.lastCumulative = cumulative
            entry.dayBytes &+= delta
            if now.timeIntervalSince(entry.hourStart) >= 3600 {
                entry.hourStart = now
                entry.hourBytes = 0
            }
            entry.hourBytes &+= delta
            entry.displayName = group.displayName
            apps[group.id] = entry
        }
        let alive = Set(groups.map(\.id))
        apps = apps.filter { alive.contains($0.key) || $0.value.dayBytes > 0 }
    }

    public func offenders(dayGB: Double, hourGB: Double) -> [AppWrites] {
        apps.values.filter { entry in
            Double(entry.dayBytes) >= dayGB * 1_073_741_824
                || Double(entry.hourBytes) >= hourGB * 1_073_741_824
        }
    }

    public var topWriter: AppWrites? {
        apps.values.max { $0.dayBytes < $1.dayBytes }
    }
}

public struct AppBaseline: Sendable, Codable {
    public var cpuAverage: Double
    public var memoryAverage: Double
    public var firstSeen: Date
    public var observedMinutes: Int
    public var lastSeen: Date

    public init(cpuAverage: Double, memoryAverage: Double, firstSeen: Date, observedMinutes: Int, lastSeen: Date) {
        self.cpuAverage = cpuAverage
        self.memoryAverage = memoryAverage
        self.firstSeen = firstSeen
        self.observedMinutes = observedMinutes
        self.lastSeen = lastSeen
    }
}

public struct BaselineStore: Sendable, Codable {
    public var baselines: [String: AppBaseline]
    public let capacity: Int

    public init(baselines: [String: AppBaseline] = [:], capacity: Int = 500) {
        self.baselines = baselines
        self.capacity = capacity
    }

    public mutating func observe(group: ProcessGroup, now: Date) -> AppBaseline {
        let alpha = 0.05
        var entry = baselines[group.id] ?? AppBaseline(
            cpuAverage: group.cpuPercent,
            memoryAverage: Double(group.footprintBytes),
            firstSeen: now,
            observedMinutes: 0,
            lastSeen: now
        )
        entry.cpuAverage = entry.cpuAverage * (1 - alpha) + group.cpuPercent * alpha
        entry.memoryAverage = entry.memoryAverage * (1 - alpha) + Double(group.footprintBytes) * alpha
        entry.observedMinutes += 1
        entry.lastSeen = now
        baselines[group.id] = entry
        trim()
        return entry
    }

    public func isLearned(_ baseline: AppBaseline, now: Date, days: Double = 7) -> Bool {
        now.timeIntervalSince(baseline.firstSeen) >= days * 86_400 && baseline.observedMinutes >= 120
    }

    private mutating func trim() {
        guard baselines.count > capacity else {
            return
        }
        let ordered = baselines.sorted { $0.value.lastSeen < $1.value.lastSeen }
        for entry in ordered.prefix(baselines.count - capacity) {
            baselines.removeValue(forKey: entry.key)
        }
    }
}

public struct AnomalyFinding: Sendable, Equatable {
    public let groupID: String
    public let displayName: String
    public let kind: Kind
    public let multiplier: Double
    public let value: Double

    public enum Kind: Sendable, Equatable {
        case cpu
        case memory
    }
}

public struct AnomalyDetector: Sendable {
    public init() {}

    public func findings(
        groups: [ProcessGroup],
        store: BaselineStore,
        now: Date,
        cpuMultiplier: Double = 5,
        cpuFloor: Double = 30,
        memoryMultiplier: Double = 3,
        memoryFloorBytes: UInt64 = 1_073_741_824
    ) -> [AnomalyFinding] {
        var results: [AnomalyFinding] = []
        for group in groups where group.isApplication {
            guard let baseline = store.baselines[group.id], store.isLearned(baseline, now: now) else {
                continue
            }
            if baseline.cpuAverage > 0, group.cpuPercent >= cpuFloor {
                let multiplier = group.cpuPercent / baseline.cpuAverage
                if multiplier >= cpuMultiplier {
                    results.append(AnomalyFinding(
                        groupID: group.id,
                        displayName: group.displayName,
                        kind: .cpu,
                        multiplier: multiplier,
                        value: group.cpuPercent
                    ))
                }
            }
            if baseline.memoryAverage > 0, group.footprintBytes >= memoryFloorBytes {
                let multiplier = Double(group.footprintBytes) / baseline.memoryAverage
                if multiplier >= memoryMultiplier {
                    results.append(AnomalyFinding(
                        groupID: group.id,
                        displayName: group.displayName,
                        kind: .memory,
                        multiplier: multiplier,
                        value: Double(group.footprintBytes)
                    ))
                }
            }
        }
        return results
    }
}

public struct OrphanCandidate: Sendable, Equatable, Identifiable {
    public let groupID: String
    public let displayName: String
    public let cpuPercent: Double
    public let footprintBytes: UInt64

    public var id: String { groupID }

    public init(groupID: String, displayName: String, cpuPercent: Double, footprintBytes: UInt64) {
        self.groupID = groupID
        self.displayName = displayName
        self.cpuPercent = cpuPercent
        self.footprintBytes = footprintBytes
    }
}

public struct OrphanClassifier: Sendable {
    public struct Input: Sendable {
        public let group: ProcessGroup
        public let parentIsLaunchd: Bool
        public let bundleAppIsRunning: Bool
        public let isLoginItem: Bool

        public init(group: ProcessGroup, parentIsLaunchd: Bool, bundleAppIsRunning: Bool, isLoginItem: Bool) {
            self.group = group
            self.parentIsLaunchd = parentIsLaunchd
            self.bundleAppIsRunning = bundleAppIsRunning
            self.isLoginItem = isLoginItem
        }
    }

    public init() {}

    public func classify(_ input: Input, minimumCPU: Double = 5, minimumFootprintBytes: UInt64 = 200 * 1_048_576) -> OrphanCandidate? {
        let group = input.group
        guard !group.isApplication else {
            return nil
        }
        guard input.parentIsLaunchd, !input.bundleAppIsRunning, !input.isLoginItem else {
            return nil
        }
        guard let path = group.members.first?.executablePath, path.contains(".app/Contents/") else {
            return nil
        }
        guard group.cpuPercent >= minimumCPU || group.footprintBytes >= minimumFootprintBytes else {
            return nil
        }
        return OrphanCandidate(
            groupID: group.id,
            displayName: group.displayName,
            cpuPercent: group.cpuPercent,
            footprintBytes: group.footprintBytes
        )
    }
}
