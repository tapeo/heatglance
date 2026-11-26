import Foundation

public struct ProtectionSettings: Sendable, Codable, Equatable {
    public var isEnabled: Bool
    public var triggerLevel: ThermalLevel
    public var sustainSeconds: Double
    public var culpritCPUThreshold: Double
    public var maxGroupsPerRound: Int
    public var maxGroupsTotal: Int
    public var secondRoundAfterSeconds: Double
    public var resumeAfterCoolSeconds: Double
    public var resumeIntervalSeconds: Double
    public var cooldownAfterResumeSeconds: Double
    public var neverPause: [String]
    public var pausedUntil: Date?

    public init(
        isEnabled: Bool = true,
        triggerLevel: ThermalLevel = .serious,
        sustainSeconds: Double = 60,
        culpritCPUThreshold: Double = 50,
        maxGroupsPerRound: Int = 3,
        maxGroupsTotal: Int = 6,
        secondRoundAfterSeconds: Double = 120,
        resumeAfterCoolSeconds: Double = 120,
        resumeIntervalSeconds: Double = 30,
        cooldownAfterResumeSeconds: Double = 600,
        neverPause: [String] = [],
        pausedUntil: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.triggerLevel = triggerLevel
        self.sustainSeconds = sustainSeconds
        self.culpritCPUThreshold = culpritCPUThreshold
        self.maxGroupsPerRound = maxGroupsPerRound
        self.maxGroupsTotal = maxGroupsTotal
        self.secondRoundAfterSeconds = secondRoundAfterSeconds
        self.resumeAfterCoolSeconds = resumeAfterCoolSeconds
        self.resumeIntervalSeconds = resumeIntervalSeconds
        self.cooldownAfterResumeSeconds = cooldownAfterResumeSeconds
        self.neverPause = neverPause
        self.pausedUntil = pausedUntil
    }

    public static let defaults = ProtectionSettings()

    public func isPaused(at date: Date) -> Bool {
        guard let pausedUntil else {
            return false
        }
        return pausedUntil > date
    }
}

public struct SuspendedGroup: Sendable, Codable, Equatable {
    public let groupID: String
    public let displayName: String
    public let cpuPercentAtSuspension: Double
    public let suspendedAt: Date

    public init(groupID: String, displayName: String, cpuPercentAtSuspension: Double, suspendedAt: Date) {
        self.groupID = groupID
        self.displayName = displayName
        self.cpuPercentAtSuspension = cpuPercentAtSuspension
        self.suspendedAt = suspendedAt
    }
}

public struct GuardState: Sendable, Codable, Equatable {
    public var hotSince: Date?
    public var coolSince: Date?
    public var suspended: [SuspendedGroup]
    public var lastRoundAt: Date?
    public var lastResumeAt: Date?
    public var interventionCount: Int
    public var blockedUntil: Date?

    public init(
        hotSince: Date? = nil,
        coolSince: Date? = nil,
        suspended: [SuspendedGroup] = [],
        lastRoundAt: Date? = nil,
        lastResumeAt: Date? = nil,
        interventionCount: Int = 0,
        blockedUntil: Date? = nil
    ) {
        self.hotSince = hotSince
        self.coolSince = coolSince
        self.suspended = suspended
        self.lastRoundAt = lastRoundAt
        self.lastResumeAt = lastResumeAt
        self.interventionCount = interventionCount
        self.blockedUntil = blockedUntil
    }
}

public struct GuardInput: Sendable {
    public let thermal: ThermalLevel
    public let presence: Presence
    public let groups: [ProcessGroup]
    public let power: PowerStateSnapshot
    public let settings: ProtectionSettings
    public let now: Date

    public init(
        thermal: ThermalLevel,
        presence: Presence,
        groups: [ProcessGroup],
        power: PowerStateSnapshot,
        settings: ProtectionSettings,
        now: Date
    ) {
        self.thermal = thermal
        self.presence = presence
        self.groups = groups
        self.power = power
        self.settings = settings
        self.now = now
    }
}

public struct PowerStateSnapshot: Sendable, Equatable {
    public let isOnACPower: Bool
    public let isCharging: Bool
    public let batteryTemperatureCelsius: Double?

    public init(isOnACPower: Bool, isCharging: Bool, batteryTemperatureCelsius: Double?) {
        self.isOnACPower = isOnACPower
        self.isCharging = isCharging
        self.batteryTemperatureCelsius = batteryTemperatureCelsius
    }

    public static let unknown = PowerStateSnapshot(isOnACPower: true, isCharging: false, batteryTemperatureCelsius: nil)
}

public enum GuardNotice: Sendable, Equatable {
    case presentAdvisory
    case noCulprit(charging: Bool, batteryCelsius: Double?)
    case suspended(groups: [SuspendedGroup])
    case returned(groups: [SuspendedGroup])
}

public enum GuardAction: Sendable, Equatable {
    case suspend(groupIDs: [String])
    case resume(groupIDs: [String])
    case notice(GuardNotice)
}

public struct GuardResult: Sendable {
    public let state: GuardState
    public let actions: [GuardAction]

    public init(state: GuardState, actions: [GuardAction]) {
        self.state = state
        self.actions = actions
    }
}
