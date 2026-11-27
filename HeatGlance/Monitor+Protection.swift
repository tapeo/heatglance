import Foundation

import HeatGlanceCore
import HeatGlanceSystem

extension Monitor {
    func evaluateGuard(sample: Sample) {
        let power = PowerSourceReader.read()
        let input = GuardInput(
            thermal: sample.thermal,
            presence: presence,
            groups: sample.groups,
            power: PowerStateSnapshot(
                isOnACPower: power.isOnACPower,
                isCharging: power.isCharging,
                batteryTemperatureCelsius: power.batteryTemperatureCelsius
            ),
            settings: settings.protection,
            now: sample.date
        )
        let before = guardState.suspended
        let result = guardPolicy.decide(input: input, state: guardState)
        guardState = result.state
        suspendedGroups = guardState.suspended
        let sendsPausedNotice = result.actions.contains { action in
            if case .notice(.suspended) = action {
                return true
            }
            return false
        }
        let pausedNotification: Bool?
        if sendsPausedNotice {
            pausedNotification = true
        } else {
            pausedNotification = nil
        }
        var events: [HistoryEvent] = []
        for action in result.actions {
            switch action {
            case let .suspend(groupIDs):
                for groupID in groupIDs {
                    if let suspended = result.state.suspended.first(where: { $0.groupID == groupID }) {
                        events.append(
                            HistoryEvent(
                                kind: .appPausedByProtection,
                                title: "Paused by protection",
                                appName: suspended.displayName,
                                value: Self.suspendValue(suspended, thermal: sample.thermal),
                                notified: pausedNotification
                            )
                        )
                    }
                    suspendGroup(groupID: groupID)
                }
            case let .resume(groupIDs):
                for groupID in groupIDs {
                    if let suspended = before.first(where: { $0.groupID == groupID }) {
                        let paused = HistoryEventValue.duration(sample.date.timeIntervalSince(suspended.suspendedAt))
                        events.append(
                            HistoryEvent(
                                kind: .appResumedByProtection,
                                title: "Resumed by protection",
                                appName: suspended.displayName,
                                value: "Paused for \(paused)"
                            )
                        )
                    }
                    resumeGroup(groupID: groupID)
                }
            case let .notice(notice):
                deliver(notice: notice)
            }
        }
        record(events)
    }

    func suspendGroup(groupID: String) {
        guard let group = latest?.groups.first(where: { $0.id == groupID }) else {
            return
        }
        Task {
            for identity in group.identities {
                if ProcessActions.suspend(identity) == .done {
                    await registry.record(
                        SuspendedProcessEntry(
                            identity: identity,
                            origin: .protection,
                            reason: "Protection paused \(group.displayName)",
                            suspendedAt: Date()
                        )
                    )
                }
            }
        }
    }

    func resumeGroup(groupID: String) {
        guard let group = latest?.groups.first(where: { $0.id == groupID }) else {
            guardState.suspended.removeAll { $0.groupID == groupID }
            suspendedGroups = guardState.suspended
            return
        }
        Task {
            for identity in group.identities {
                _ = ProcessActions.resume(identity)
                await registry.remove(identity)
            }
            guardState.suspended.removeAll { $0.groupID == groupID }
            suspendedGroups = guardState.suspended
        }
    }

    func perform(_ kind: ProcessActionKind, identity: ProcessIdentity) async {
        switch kind {
        case .suspend:
            if ProcessActions.suspend(identity) == .done {
                await registry.record(
                    SuspendedProcessEntry(
                        identity: identity,
                        origin: .manual,
                        reason: "Suspended from the menu",
                        suspendedAt: Date()
                    )
                )
            }
        case .resume:
            _ = ProcessActions.resume(identity)
            await registry.remove(identity)
        case .quit:
            _ = ProcessActions.quit(identity)
        case .forceQuit:
            _ = ProcessActions.forceQuit(identity)
        }
    }

    static func suspendValue(_ group: SuspendedGroup, thermal: ThermalLevel) -> String {
        String(format: "CPU %.0f%%, thermal %@", group.cpuPercentAtSuspension, thermal.title.lowercased())
    }
}
