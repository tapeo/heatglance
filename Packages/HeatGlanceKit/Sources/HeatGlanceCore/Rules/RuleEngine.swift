import Foundation

public struct ConditionStamp: Sendable, Codable, Hashable {
    public let startedAt: Date
    public let lastSeenAt: Date

    public init(startedAt: Date, lastSeenAt: Date) {
        self.startedAt = startedAt
        self.lastSeenAt = lastSeenAt
    }
}

public struct RuleState: Sendable, Codable {
    public var firingSince: [String: ConditionStamp]
    public var clearingSince: [String: ConditionStamp]
    public var lastAlertAt: [String: Date]

    public init(
        firingSince: [String: ConditionStamp] = [:],
        clearingSince: [String: ConditionStamp] = [:],
        lastAlertAt: [String: Date] = [:]
    ) {
        self.firingSince = firingSince
        self.clearingSince = clearingSince
        self.lastAlertAt = lastAlertAt
    }

    public mutating func reset() {
        firingSince.removeAll()
        clearingSince.removeAll()
        lastAlertAt.removeAll()
    }

    public func isActive(rule: String, key: String) -> Bool {
        firingSince["\(rule)|\(key)"] != nil
    }
}

public struct EvaluationResult: Sendable {
    public let state: RuleState
    public let alerts: [Alert]

    public init(state: RuleState, alerts: [Alert]) {
        self.state = state
        self.alerts = alerts
    }
}

public struct RuleEngine {
    private let catalog: RuleCatalog
    private let enabledRuleIDs: Set<String>

    public init(catalog: RuleCatalog = RuleCatalog(), enabledRuleIDs: Set<String>? = nil) {
        self.catalog = catalog
        if let enabledRuleIDs {
            self.enabledRuleIDs = enabledRuleIDs
        } else {
            self.enabledRuleIDs = Set(catalog.rules.map(\.id))
        }
    }

    public func evaluate(
        sample: Sample,
        settings: AppSettings,
        state: RuleState,
        now: Date,
        ignoredKeys: Set<String> = []
    ) -> EvaluationResult {
        var nextState = state
        var alerts: [Alert] = []

        for rule in catalog.rules {
            guard enabledRuleIDs.contains(rule.id) else {
                continue
            }
            if rule.scope == .system {
                evaluateTarget(
                    rule: rule,
                    key: "system",
                    group: nil,
                    conditionHolds: rule.condition(sample, settings),
                    settings: settings,
                    state: &nextState,
                    alerts: &alerts,
                    now: now,
                    ignoredKeys: ignoredKeys
                )
                continue
            }
            for group in rule.targetGroups(in: sample) {
                evaluateTarget(
                    rule: rule,
                    key: group.id,
                    group: group,
                    conditionHolds: groupCondition(rule: rule, group: group, sample: sample, settings: settings),
                    settings: settings,
                    state: &nextState,
                    alerts: &alerts,
                    now: now,
                    ignoredKeys: ignoredKeys
                )
            }
        }

        return EvaluationResult(state: nextState, alerts: alerts)
    }

    private func groupCondition(
        rule: RuleDefinition,
        group: ProcessGroup,
        sample: Sample,
        settings: AppSettings
    ) -> Bool {
        let single = Sample(
            date: sample.date,
            thermal: sample.thermal,
            temperatureCelsius: sample.temperatureCelsius,
            memoryPressure: sample.memoryPressure,
            swapUsedBytes: sample.swapUsedBytes,
            physicalMemoryBytes: sample.physicalMemoryBytes,
            systemCPUPercent: sample.systemCPUPercent,
            diskAvailableBytes: sample.diskAvailableBytes,
            diskTotalBytes: sample.diskTotalBytes,
            groups: [group]
        )
        return rule.condition(single, settings)
    }

    private func evaluateTarget(
        rule: RuleDefinition,
        key: String,
        group: ProcessGroup?,
        conditionHolds: Bool,
        settings: AppSettings,
        state: inout RuleState,
        alerts: inout [Alert],
        now: Date,
        ignoredKeys: Set<String>
    ) {
        let stateKey = "\(rule.id)|\(key)"
        if ignoredKeys.contains(stateKey) || ignoredKeys.contains(rule.id) {
            state.firingSince.removeValue(forKey: stateKey)
            state.clearingSince.removeValue(forKey: stateKey)
            return
        }

        if conditionHolds {
            state.clearingSince.removeValue(forKey: stateKey)
            if state.firingSince[stateKey] == nil {
                state.firingSince[stateKey] = ConditionStamp(startedAt: now, lastSeenAt: now)
            }
            guard let stamp = state.firingSince[stateKey] else {
                return
            }
            if now.timeIntervalSince(stamp.startedAt) < rule.sustainSeconds {
                return
            }
            if let last = state.lastAlertAt[stateKey],
               now.timeIntervalSince(last) < settings.cooldownSeconds {
                return
            }
            let alert = Alert(
                ruleID: rule.id,
                title: rule.title,
                level: rule.level,
                groupID: group?.id,
                groupName: group?.displayName,
                date: now,
                message: ""
            )
            alerts.append(alert)
            state.lastAlertAt[stateKey] = now
            return
        }

        guard state.firingSince[stateKey] != nil else {
            state.clearingSince.removeValue(forKey: stateKey)
            return
        }
        if state.clearingSince[stateKey] == nil {
            state.clearingSince[stateKey] = ConditionStamp(startedAt: now, lastSeenAt: now)
        }
        guard let clearing = state.clearingSince[stateKey] else {
            return
        }
        let clearingDuration = now.timeIntervalSince(clearing.startedAt)
        if clearingDuration > 0 && clearingDuration >= rule.clearSeconds {
            state.firingSince.removeValue(forKey: stateKey)
            state.clearingSince.removeValue(forKey: stateKey)
        }
    }

    public func activeLevels(state: RuleState) -> [HealthLevel] {
        var levels: [HealthLevel] = []
        for (key, _) in state.firingSince {
            let ruleID = String(key.split(separator: "|").first ?? "")
            guard let rule = catalog.definition(id: ruleID) else {
                continue
            }
            levels.append(rule.level)
        }
        return levels
    }
}
