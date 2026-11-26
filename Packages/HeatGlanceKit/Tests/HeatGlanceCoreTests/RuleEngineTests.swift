import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("Rule engine")
struct RuleEngineTests {
    let settings = AppSettings.defaults

    @Test("A thermal alert needs the sustain duration")
    func thermalSustain() {
        let engine = RuleEngine()
        let start = Fixtures.baseDate
        var state = RuleState()

        let first = engine.evaluate(
            sample: Fixtures.sample(thermal: .serious),
            settings: settings,
            state: state,
            now: start
        )
        state = first.state
        #expect(first.alerts.isEmpty)

        let second = engine.evaluate(
            sample: Fixtures.sample(thermal: .serious),
            settings: settings,
            state: state,
            now: start.addingTimeInterval(59)
        )
        #expect(second.alerts.isEmpty)

        let third = engine.evaluate(
            sample: Fixtures.sample(thermal: .serious),
            settings: settings,
            state: second.state,
            now: start.addingTimeInterval(61)
        )
        #expect(third.alerts.count == 1)
        #expect(third.alerts.first?.ruleID == "thermal_serious")
        #expect(third.alerts.first?.level == .elevated)
    }

    @Test("Critical thermal alerts immediately")
    func thermalCriticalImmediate() {
        let engine = RuleEngine()
        let result = engine.evaluate(
            sample: Fixtures.sample(thermal: .critical),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate
        )
        #expect(result.alerts.contains { $0.ruleID == "thermal_critical" })
    }

    @Test("Fair thermal state clears after the clear window")
    func thermalClears() {
        let engine = RuleEngine()
        let start = Fixtures.baseDate
        var state = RuleState()

        state = engine.evaluate(
            sample: Fixtures.sample(thermal: .serious),
            settings: settings,
            state: state,
            now: start
        ).state
        state = engine.evaluate(
            sample: Fixtures.sample(thermal: .serious),
            settings: settings,
            state: state,
            now: start.addingTimeInterval(61)
        ).state
        #expect(state.isActive(rule: "thermal_serious", key: "system"))

        state = engine.evaluate(
            sample: Fixtures.sample(thermal: .nominal),
            settings: settings,
            state: state,
            now: start.addingTimeInterval(70)
        ).state
        #expect(state.isActive(rule: "thermal_serious", key: "system"))

        state = engine.evaluate(
            sample: Fixtures.sample(thermal: .nominal),
            settings: settings,
            state: state,
            now: start.addingTimeInterval(71)
        ).state
        #expect(!state.isActive(rule: "thermal_serious", key: "system"))    }

    @Test("Cooldown blocks a repeated alert")
    func cooldown() {
        let engine = RuleEngine()
        let start = Fixtures.baseDate
        var state = RuleState()

        state = engine.evaluate(
            sample: Fixtures.sample(thermal: .critical),
            settings: settings,
            state: state,
            now: start
        ).state

        let repeated = engine.evaluate(
            sample: Fixtures.sample(thermal: .critical),
            settings: settings,
            state: state,
            now: start.addingTimeInterval(60)
        )
        #expect(repeated.alerts.isEmpty)
    }

    @Test("A process rule fires per application group")
    func processRule() {
        let engine = RuleEngine()
        let start = Fixtures.baseDate
        var state = RuleState()
        let sample = Fixtures.sample(groups: [Fixtures.group(cpu: 200)])
        state = engine.evaluate(sample: sample, settings: settings, state: state, now: start).state
        let result = engine.evaluate(
            sample: sample,
            settings: settings,
            state: state,
            now: start.addingTimeInterval(121)
        )
        #expect(result.alerts.count == 1)
        #expect(result.alerts.first?.groupID == "com.example.app")
        #expect(result.alerts.first?.message.hasPrefix("Example:") == true)
    }

    @Test("Ignored keys disable a rule")
    func ignoredRule() {
        let engine = RuleEngine()
        let result = engine.evaluate(
            sample: Fixtures.sample(thermal: .critical),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate,
            ignoredKeys: ["thermal_critical"]
        )
        #expect(result.alerts.isEmpty)
    }

    @Test("Disk free triggers at or below the GB threshold")
    func diskFreeBelowThreshold() {
        let engine = RuleEngine()
        let fifteenGB = Int64(15) * 1_073_741_824
        let result = engine.evaluate(
            sample: Fixtures.sample(diskAvailable: fifteenGB, diskTotal: 1_000_000_000_000),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate
        )
        #expect(result.alerts.contains { $0.ruleID == "disk_free" })
    }

    @Test("Disk free triggers exactly at the threshold")
    func diskFreeAtThreshold() {
        let engine = RuleEngine()
        let twentyGB = Int64(20) * 1_073_741_824
        let result = engine.evaluate(
            sample: Fixtures.sample(diskAvailable: twentyGB, diskTotal: 1_000_000_000_000),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate
        )
        #expect(result.alerts.contains { $0.ruleID == "disk_free" })
    }

    @Test("A low free ratio alone does not trigger the disk rule")
    func diskFreeIgnoresRatio() {
        let engine = RuleEngine()
        let result = engine.evaluate(
            sample: Fixtures.sample(diskAvailable: 50_000_000_000, diskTotal: 1_000_000_000_000),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate
        )
        #expect(!result.alerts.contains { $0.ruleID == "disk_free" })
    }

    @Test("An unreadable disk does not trigger the disk rule")
    func diskFreeUnreadable() {
        let engine = RuleEngine()
        let result = engine.evaluate(
            sample: Fixtures.sample(diskAvailable: 0, diskTotal: 0),
            settings: settings,
            state: RuleState(),
            now: Fixtures.baseDate
        )
        #expect(!result.alerts.contains { $0.ruleID == "disk_free" })
    }

    @Test("Swap triggers above the ratio")
    func swap() {
        let engine = RuleEngine()
        let physical = UInt64(16) * 1_073_741_824
        let start = Fixtures.baseDate
        var state = RuleState()
        let sample = Fixtures.sample(swapUsed: physical / 2, physical: physical)
        state = engine.evaluate(sample: sample, settings: settings, state: state, now: start).state
        let result = engine.evaluate(
            sample: sample,
            settings: settings,
            state: state,
            now: start.addingTimeInterval(301)
        )
        #expect(result.alerts.contains { $0.ruleID == "swap_high" })
    }

    @Test("A rule waiting for its sustain is not active")
    func activeRulesSustain() {
        let engine = RuleEngine()
        let state = RuleState(
            firingSince: [
                "thermal_serious|system": ConditionStamp(startedAt: Fixtures.baseDate, lastSeenAt: Fixtures.baseDate),
            ]
        )
        #expect(engine.activeRules(state: state, now: Fixtures.baseDate.addingTimeInterval(30)).isEmpty)

        let active = engine.activeRules(state: state, now: Fixtures.baseDate.addingTimeInterval(60))
        #expect(active.count == 1)
        #expect(active.first?.ruleID == "thermal_serious")
        #expect(active.first?.groupID == nil)
    }

    @Test("Critical rules come first")
    func activeRulesOrder() {
        let engine = RuleEngine()
        let state = RuleState(
            firingSince: [
                "thermal_serious|system": ConditionStamp(startedAt: Fixtures.baseDate, lastSeenAt: Fixtures.baseDate),
                "memory_critical|system": ConditionStamp(
                    startedAt: Fixtures.baseDate.addingTimeInterval(10),
                    lastSeenAt: Fixtures.baseDate.addingTimeInterval(10)
                ),
            ]
        )
        let active = engine.activeRules(state: state, now: Fixtures.baseDate.addingTimeInterval(100))
        #expect(active.first?.ruleID == "memory_critical")
        #expect(active.last?.ruleID == "thermal_serious")
    }

    @Test("Group rules carry the group id")
    func activeRulesGroup() {
        let engine = RuleEngine()
        let state = RuleState(
            firingSince: [
                "process_cpu|com.example.app": ConditionStamp(startedAt: Fixtures.baseDate, lastSeenAt: Fixtures.baseDate),
            ]
        )
        let active = engine.activeRules(state: state, now: Fixtures.baseDate.addingTimeInterval(200))
        #expect(active.first?.groupID == "com.example.app")
    }

    @Test("Unknown rule keys are skipped")
    func activeRulesUnknown() {
        let engine = RuleEngine()
        let state = RuleState(
            firingSince: [
                "missing|system": ConditionStamp(startedAt: Fixtures.baseDate, lastSeenAt: Fixtures.baseDate),
            ]
        )
        #expect(engine.activeRules(state: state, now: Fixtures.baseDate.addingTimeInterval(200)).isEmpty)
    }
}

@Suite("Ignore list and cooldown")
struct IgnoreListTests {
    @Test("An entry without expiry never expires")
    func permanentEntry() {
        let entry = IgnoreEntry(kind: .rule, value: "thermal_serious", label: "Thermal", expiresAt: nil)
        #expect(entry.isActive(at: Fixtures.baseDate))
    }

    @Test("An expired entry is inactive")
    func expiredEntry() {
        let entry = IgnoreEntry(
            kind: .group,
            value: "com.example.app",
            label: "Example",
            expiresAt: Fixtures.baseDate.addingTimeInterval(60)
        )
        #expect(entry.isActive(at: Fixtures.baseDate))
        #expect(!entry.isActive(at: Fixtures.baseDate.addingTimeInterval(61)))
    }

    @Test("Prune removes only the expired entries")
    func prune() {
        var list = IgnoreList(entries: [
            IgnoreEntry(kind: .rule, value: "a", label: "A", expiresAt: nil),
            IgnoreEntry(kind: .rule, value: "b", label: "B", expiresAt: Fixtures.baseDate),
        ])
        list.prune(at: Fixtures.baseDate.addingTimeInterval(1))
        #expect(list.entries.count == 1)
        #expect(list.entries.first?.value == "a")
    }

    @Test("Adding the same key replaces the old entry")
    func replace() {
        var list = IgnoreList()
        list.add(IgnoreEntry(kind: .group, value: "com.example.app", label: "Old", expiresAt: nil))
        list.add(IgnoreEntry(kind: .group, value: "com.example.app", label: "New", expiresAt: nil))
        #expect(list.entries.count == 1)
        #expect(list.entries.first?.label == "New")
    }

    @Test("Cooldown expires after the window")
    func cooldownWindow() {
        var cooldown = Cooldown()
        cooldown.record(key: "k", now: Fixtures.baseDate)
        #expect(!cooldown.allows(key: "k", now: Fixtures.baseDate.addingTimeInterval(800), window: 900, escalated: false))
        #expect(cooldown.allows(key: "k", now: Fixtures.baseDate.addingTimeInterval(901), window: 900, escalated: false))
        #expect(cooldown.allows(key: "k", now: Fixtures.baseDate.addingTimeInterval(10), window: 900, escalated: true))
    }
}
