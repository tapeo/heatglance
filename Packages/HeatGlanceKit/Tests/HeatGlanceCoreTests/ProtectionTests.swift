import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("Presence policy")
struct PresencePolicyTests {
    let policy = PresencePolicy()
    let settings = PresenceSettings.defaults

    @Test("An active user is present")
    func present() {
        let signals = PresenceSignals(idleSeconds: 5)
        #expect(policy.evaluate(signals, settings: settings) == .present)
    }

    @Test("A locked screen means away")
    func locked() {
        let signals = PresenceSignals(screenIsLocked: true, idleSeconds: 0)
        #expect(policy.evaluate(signals, settings: settings) == .absent)
    }

    @Test("Asleep screens mean away")
    func asleep() {
        #expect(policy.evaluate(PresenceSignals(screensAreAsleep: true), settings: settings) == .absent)
    }

    @Test("An inactive session means away")
    func session() {
        #expect(policy.evaluate(PresenceSignals(sessionIsActive: false), settings: settings) == .absent)
    }

    @Test("A screen saver means away")
    func screenSaver() {
        #expect(policy.evaluate(PresenceSignals(screenSaverIsRunning: true), settings: settings) == .absent)
    }

    @Test("Idle beyond the threshold means away")
    func idle() {
        #expect(policy.evaluate(PresenceSignals(idleSeconds: 301), settings: settings) == .absent)
    }

    @Test("A video keeps the user present until the passive cap")
    func passive() {
        let signals = PresenceSignals(
            idleSeconds: 1200,
            displaySleepPrevented: true
        )
        #expect(policy.evaluate(signals, settings: settings) == .passive)

        let tooLong = PresenceSignals(
            idleSeconds: 3700,
            displaySleepPrevented: true
        )
        #expect(policy.evaluate(tooLong, settings: settings) == .absent)
    }

    @Test("A disabled passive signal does not keep the user present")
    func passiveDisabled() {
        var disabled = settings
        disabled.useDisplaySleepAssertion = false
        let signals = PresenceSignals(idleSeconds: 1200, displaySleepPrevented: true)
        #expect(policy.evaluate(signals, settings: disabled) == .absent)
    }

    @Test("A microphone keeps the user present")
    func microphone() {
        let signals = PresenceSignals(idleSeconds: 900, microphoneInUse: true)
        #expect(policy.evaluate(signals, settings: settings) == .passive)
    }
}

@Suite("Protection explanation")
struct ProtectionExplanationTests {
    @Test("Protection is on by default")
    func enabledByDefault() {
        #expect(ProtectionSettings.defaults.isEnabled)
        #expect(ProtectionSettings().isEnabled)
    }

    @Test("Explanation uses the current settings")
    func explanationText() {
        let paragraphs = ProtectionExplanation
            .sections(protection: .defaults, presence: .defaults)
            .flatMap(\.paragraphs)
            .joined(separator: " ")
        #expect(paragraphs.contains("1 minute"))
        #expect(paragraphs.contains("50% CPU"))
        #expect(paragraphs.contains("up to 3 per round"))
        #expect(paragraphs.contains("once 6 apps are paused"))
        #expect(paragraphs.contains("2 minutes"))
        #expect(paragraphs.contains("30 seconds"))
        #expect(paragraphs.contains("10 minutes"))
        #expect(paragraphs.contains("5 minutes"))
        #expect(paragraphs.contains("15 minutes"))

        var slow = ProtectionSettings.defaults
        slow.sustainSeconds = 90
        let slowText = ProtectionExplanation
            .sections(protection: slow, presence: .defaults)
            .flatMap(\.paragraphs)
            .joined(separator: " ")
        #expect(slowText.contains("90 seconds"))
    }

    @Test("Never pause lists the apps")
    func neverPauseList() {
        var settings = ProtectionSettings.defaults
        settings.neverPause = ["com.example.app"]
        let paragraphs = ProtectionExplanation
            .sections(protection: settings, presence: .defaults)
            .flatMap(\.paragraphs)
            .joined(separator: " ")
        #expect(paragraphs.contains("com.example.app"))
    }

    @Test("Passive signals are listed only when enabled")
    func passiveSignals() {
        var presence = PresenceSettings.defaults
        presence.useDisplaySleepAssertion = false
        presence.useMicrophone = false
        presence.useCamera = false
        let paragraphs = ProtectionExplanation
            .sections(protection: .defaults, presence: presence)
            .flatMap(\.paragraphs)
            .joined(separator: " ")
        #expect(!paragraphs.contains("still count as present"))
    }

    @Test("Durations read naturally")
    func durations() {
        #expect(ProtectionExplanation.duration(1) == "1 second")
        #expect(ProtectionExplanation.duration(45) == "45 seconds")
        #expect(ProtectionExplanation.duration(60) == "1 minute")
        #expect(ProtectionExplanation.duration(90) == "90 seconds")
        #expect(ProtectionExplanation.duration(600) == "10 minutes")
        #expect(ProtectionExplanation.duration(3600) == "1 hour")
        #expect(ProtectionExplanation.duration(7200) == "2 hours")
    }
}

@Suite("Thermal guard policy")
struct ThermalGuardPolicyTests {
    let policy = ThermalGuardPolicy()
    let start = Fixtures.baseDate

    func input(
        thermal: ThermalLevel,
        presence: Presence,
        groups: [ProcessGroup],
        settings: ProtectionSettings = .defaults,
        date: Date,
        charging: Bool = false,
        battery: Double? = nil
    ) -> GuardInput {
        GuardInput(
            thermal: thermal,
            presence: presence,
            groups: groups,
            power: PowerStateSnapshot(isOnACPower: true, isCharging: charging, batteryTemperatureCelsius: battery),
            settings: settings,
            now: date
        )
    }

    var enabled: ProtectionSettings {
        var settings = ProtectionSettings.defaults
        settings.isEnabled = true
        settings.sustainSeconds = 60
        return settings
    }

    @Test("Nothing happens while the user is present")
    func presentOnlyNotifies() {
        let groups = [Fixtures.group(cpu: 200)]
        var state = GuardState()
        var result = policy.decide(
            input: input(thermal: .serious, presence: .present, groups: groups, settings: enabled, date: start),
            state: state
        )
        state = result.state
        result = policy.decide(
            input: input(thermal: .serious, presence: .present, groups: groups, settings: enabled, date: start.addingTimeInterval(120)),
            state: state
        )
        #expect(result.state.suspended.isEmpty)
        #expect(result.actions.contains(.notice(.presentAdvisory)))
    }

    @Test("Away and hot suspends the culprit after the sustain time")
    func suspendsAfterSustain() {
        let groups = [Fixtures.group(cpu: 200)]
        let first = policy.decide(
            input: input(thermal: .serious, presence: .absent, groups: groups, settings: enabled, date: start),
            state: GuardState()
        )
        #expect(first.actions.isEmpty)

        let second = policy.decide(
            input: input(thermal: .serious, presence: .absent, groups: groups, settings: enabled, date: start.addingTimeInterval(61)),
            state: first.state
        )
        #expect(second.actions.contains(.suspend(groupIDs: ["com.example.app"])))
        #expect(second.state.suspended.count == 1)
    }

    @Test("No culprit means a notice, with charging details")
    func noCulprit() {
        let result = policy.decide(
            input: input(
                thermal: .serious,
                presence: .absent,
                groups: [Fixtures.group(cpu: 10)],
                settings: enabled,
                date: start.addingTimeInterval(61),
                charging: true,
                battery: 41
            ),
            state: GuardState(hotSince: start)
        )
        #expect(result.actions.contains(.notice(.noCulprit(charging: true, batteryCelsius: 41))))
        #expect(result.state.suspended.isEmpty)
    }

    @Test("At most three groups per round and six in total")
    func limits() {
        var groups: [ProcessGroup] = []
        for index in 0..<8 {
            groups.append(Fixtures.group(id: "com.example.app\(index)", name: "App \(index)", cpu: 100 - Double(index)))
        }
        var state = GuardState(hotSince: start)
        var suspended = 0
        var date = start
        for _ in 0..<4 {
            date = date.addingTimeInterval(130)
            let result = policy.decide(
                input: input(thermal: .serious, presence: .absent, groups: groups, settings: enabled, date: date),
                state: state
            )
            state = result.state
            suspended = state.suspended.count
        }
        #expect(suspended <= 6)
    }

    @Test("Turning the switch off resumes everything")
    func offResumes() {
        let state = GuardState(
            suspended: [SuspendedGroup(groupID: "com.example.app", displayName: "Example", cpuPercentAtSuspension: 90, suspendedAt: start)]
        )
        var settings = enabled
        settings.isEnabled = false
        let result = policy.decide(
            input: input(thermal: .serious, presence: .absent, groups: [], settings: settings, date: start.addingTimeInterval(10)),
            state: state
        )
        #expect(result.actions.contains(.resume(groupIDs: ["com.example.app"])))
        #expect(result.state.suspended.isEmpty)
    }

    @Test("A paused protection resumes everything and suspends nothing")
    func paused() {
        let state = GuardState(
            suspended: [SuspendedGroup(groupID: "com.example.app", displayName: "Example", cpuPercentAtSuspension: 90, suspendedAt: start)]
        )
        var settings = enabled
        settings.pausedUntil = start.addingTimeInterval(3600)
        let result = policy.decide(
            input: input(thermal: .serious, presence: .absent, groups: [Fixtures.group(cpu: 200)], settings: settings, date: start.addingTimeInterval(10)),
            state: state
        )
        #expect(result.actions.contains(.resume(groupIDs: ["com.example.app"])))
        #expect(result.state.suspended.isEmpty)
    }

    @Test("The never pause list is respected")
    func neverPause() {
        var settings = enabled
        settings.neverPause = ["com.example.app"]
        let result = policy.decide(
            input: input(
                thermal: .serious,
                presence: .absent,
                groups: [Fixtures.group(cpu: 300)],
                settings: settings,
                date: start.addingTimeInterval(61)
            ),
            state: GuardState(hotSince: start)
        )
        #expect(result.state.suspended.isEmpty)
        #expect(result.actions.contains(.notice(.noCulprit(charging: false, batteryCelsius: nil))))
    }

    @Test("The lightest group resumes first after the Mac cools down")
    func resumesLightest() {
        var state = GuardState(
            coolSince: start,
            suspended: [
                SuspendedGroup(groupID: "heavy", displayName: "Heavy", cpuPercentAtSuspension: 200, suspendedAt: start),
                SuspendedGroup(groupID: "light", displayName: "Light", cpuPercentAtSuspension: 60, suspendedAt: start),
            ]
        )
        let result = policy.decide(
            input: input(thermal: .fair, presence: .present, groups: [], settings: enabled, date: start.addingTimeInterval(121)),
            state: state
        )
        state = result.state
        #expect(result.actions.contains(.resume(groupIDs: ["light"])))
        #expect(state.suspended.count == 1)
    }
}
