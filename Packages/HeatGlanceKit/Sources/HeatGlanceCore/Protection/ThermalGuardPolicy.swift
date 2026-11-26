import Foundation

public struct ThermalGuardPolicy {
    public init() {}

    public func decide(input: GuardInput, state: GuardState) -> GuardResult {
        var next = state
        var actions: [GuardAction] = []
        let settings = input.settings

        let isHot = input.thermal >= settings.triggerLevel
        if isHot {
            next.coolSince = nil
            if next.hotSince == nil {
                next.hotSince = input.now
            }
        } else {
            next.hotSince = nil
            if next.coolSince == nil {
                next.coolSince = input.now
            }
        }

        if !settings.isEnabled || settings.isPaused(at: input.now) {
            if !next.suspended.isEmpty {
                actions.append(.resume(groupIDs: next.suspended.map(\.groupID)))
                next.suspended = []
            }
            next.hotSince = nil
            return GuardResult(state: next, actions: actions)
        }

        if !next.suspended.isEmpty {
            actions.append(contentsOf: resumeIfCool(input: input, state: &next))
        }

        guard isHot, let hotSince = next.hotSince else {
            return GuardResult(state: next, actions: actions)
        }

        if input.presence == .absent {
            if input.now.timeIntervalSince(hotSince) >= settings.sustainSeconds {
                let culprits = culprits(in: input, excluding: next.suspended.map(\.groupID))
                if culprits.isEmpty {
                    actions.append(.notice(.noCulprit(
                        charging: input.power.isCharging,
                        batteryCelsius: input.power.batteryTemperatureCelsius
                    )))
                    return GuardResult(state: next, actions: actions)
                }
                if canStartRound(state: next, now: input.now, settings: settings) {
                    let selected = Array(culprits.prefix(settings.maxGroupsPerRound))
                    let suspended = selected.map {
                        SuspendedGroup(
                            groupID: $0.id,
                            displayName: $0.displayName,
                            cpuPercentAtSuspension: $0.cpuPercent,
                            suspendedAt: input.now
                        )
                    }
                    next.suspended.append(contentsOf: suspended)
                    next.lastRoundAt = input.now
                    next.interventionCount += 1
                    actions.append(.suspend(groupIDs: selected.map(\.id)))
                    actions.append(.notice(.suspended(groups: suspended)))
                }
            }
        } else {
            actions.append(.notice(.presentAdvisory))
        }

        return GuardResult(state: next, actions: actions)
    }

    private func resumeIfCool(input: GuardInput, state: inout GuardState) -> [GuardAction] {
        guard input.thermal < input.settings.triggerLevel else {
            state.coolSince = nil
            return []
        }
        guard let coolSince = state.coolSince else {
            return []
        }
        let settings = input.settings
        guard input.now.timeIntervalSince(coolSince) >= settings.resumeAfterCoolSeconds else {
            return []
        }
        guard !state.suspended.isEmpty else {
            return []
        }
        if let lastResume = state.lastResumeAt,
           input.now.timeIntervalSince(lastResume) < settings.resumeIntervalSeconds {
            return []
        }
        let lightest = state.suspended.min { $0.cpuPercentAtSuspension < $1.cpuPercentAtSuspension }
        guard let lightest else {
            return []
        }
        state.suspended.removeAll { $0.groupID == lightest.groupID }
        state.lastResumeAt = input.now
        state.blockedUntil = input.now.addingTimeInterval(settings.cooldownAfterResumeSeconds)
        return [.resume(groupIDs: [lightest.groupID])]
    }

    private func canStartRound(state: GuardState, now: Date, settings: ProtectionSettings) -> Bool {
        if state.suspended.count >= settings.maxGroupsTotal {
            return false
        }
        if let blockedUntil = state.blockedUntil, now < blockedUntil {
            return false
        }
        guard let lastRound = state.lastRoundAt else {
            return true
        }
        return now.timeIntervalSince(lastRound) >= settings.secondRoundAfterSeconds
    }

    private func culprits(in input: GuardInput, excluding suspendedIDs: [String]) -> [ProcessGroup] {
        input.groups
            .filter { group in
                guard group.isApplication else {
                    return false
                }
                if suspendedIDs.contains(group.id) {
                    return false
                }
                if input.settings.neverPause.contains(group.id) {
                    return false
                }
                if group.displayName == "HeatGlance" {
                    return false
                }
                return group.cpuPercent >= input.settings.culpritCPUThreshold
            }
            .sorted { $0.cpuPercent > $1.cpuPercent }
    }
}
