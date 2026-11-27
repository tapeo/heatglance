import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("History events")
struct HistoryEventTests {
    let start = Fixtures.baseDate

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    var utc: TimeZone {
        TimeZone(secondsFromGMT: 0) ?? .current
    }

    func rule(since: Date, targetKey: String = "com.example.app", ruleID: String = "process_cpu") -> ActiveRule {
        ActiveRule(
            ruleID: ruleID,
            title: "Using a lot of CPU",
            level: .elevated,
            isSystemWide: false,
            targetKey: targetKey,
            since: since
        )
    }

    @Test("A new alert records its value and notification")
    func alertStarted() throws {
        let group = Fixtures.group(id: "com.example.app", name: "Example", cpu: 182)
        let sample = Fixtures.sample(date: start, groups: [group])
        let active = rule(since: start)

        let events = HistoryEventLog().alertEvents(previous: [], current: [active], sample: sample, notifiedKeys: [active.id])
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.kind == .alertStarted)
        #expect(event.date == start)
        #expect(event.key == active.id)
        #expect(event.title == "Using a lot of CPU")
        #expect(event.appName == "Example")
        #expect(event.value == "CPU 182%")
        #expect(event.notified == true)
    }

    @Test("An alert without a notification leaves the flag empty")
    func alertStartedQuietly() throws {
        let group = Fixtures.group(id: "com.example.app", name: "Example", cpu: 90)
        let sample = Fixtures.sample(date: start, groups: [group])
        let active = rule(since: start)

        let events = HistoryEventLog().alertEvents(previous: [], current: [active], sample: sample, notifiedKeys: [])
        let event = try #require(events.first)
        #expect(event.notified == nil)
    }

    @Test("A cleared alert keeps its app and lasts")
    func alertEnded() throws {
        let group = Fixtures.group(id: "com.example.app", name: "Example", cpu: 182)
        let sample = Fixtures.sample(date: start, groups: [group])
        let active = rule(since: start.addingTimeInterval(-720))

        var log = HistoryEventLog()
        let started = log.alertEvents(previous: [], current: [active], sample: sample, notifiedKeys: [])
        log.append(started)

        let events = log.alertEvents(previous: [active], current: [], sample: sample, notifiedKeys: [])
        let event = try #require(events.first)
        #expect(event.kind == .alertEnded)
        #expect(event.key == active.id)
        #expect(event.appName == "Example")
        #expect(event.value == "Lasted 12 min")

        #expect(log.alertEvents(previous: [active], current: [active], sample: sample, notifiedKeys: []).isEmpty)
    }

    @Test("The alert key matches the active rule")
    func activeRuleKey() {
        let alert = Alert(
            ruleID: "process_cpu",
            title: "Using a lot of CPU",
            level: .elevated,
            groupID: "com.example.app",
            groupName: "Example",
            date: start,
            message: ""
        )
        #expect(alert.activeRuleID == rule(since: start).id)

        let system = Alert(
            ruleID: "system_cpu",
            title: "CPU is pegged",
            level: .elevated,
            groupID: nil,
            groupName: nil,
            date: start,
            message: ""
        )
        let systemRule = ActiveRule(
            ruleID: "system_cpu",
            title: "CPU is pegged",
            level: .elevated,
            isSystemWide: true,
            targetKey: "system",
            since: start
        )
        #expect(system.activeRuleID == systemRule.id)
    }

    @Test("Coming back reports the time away")
    func presence() throws {
        var log = HistoryEventLog()
        let away = try #require(log.presenceEvent(previous: .present, current: .absent, at: start, notified: false))
        #expect(away.kind == .userAway)
        log.append([away])

        let back = try #require(
            log.presenceEvent(previous: .absent, current: .present, at: start.addingTimeInterval(1800), notified: true)
        )
        #expect(back.kind == .userBack)
        #expect(back.value == "Away 30 min")
        #expect(back.notified == true)

        #expect(log.presenceEvent(previous: .present, current: .passive, at: start, notified: false) == nil)
        #expect(log.presenceEvent(previous: .passive, current: .present, at: start, notified: false) == nil)
    }

    @Test("Protection changes become rows")
    func protection() {
        let log = HistoryEventLog()
        let until = start.addingTimeInterval(3600)

        #expect(log.protectionEvent(previous: .on, current: .off, at: start)?.kind == .protectionOff)

        let snoozed = log.protectionEvent(previous: .on, current: .paused(until: until), at: start, calendar: calendar, timeZone: utc)
        #expect(snoozed?.kind == .protectionSnoozed)
        #expect(snoozed?.value == "Until 23:13")

        let resumed = log.protectionEvent(previous: .paused(until: until), current: .on, at: until.addingTimeInterval(60))
        #expect(resumed?.kind == .protectionOn)
        #expect(resumed?.title == "Protection resumed")
        #expect(resumed?.date == until)

        let turnedOn = log.protectionEvent(previous: .paused(until: until), current: .on, at: start)
        #expect(turnedOn?.title == "Protection turned on")
        #expect(turnedOn?.date == start)

        #expect(log.protectionEvent(previous: .on, current: .on, at: start) == nil)
    }

    @Test("Mode reads the settings")
    func protectionMode() {
        var settings = ProtectionSettings.defaults
        settings.pausedUntil = start.addingTimeInterval(3600)
        #expect(settings.mode(at: start) == .paused(until: start.addingTimeInterval(3600)))
        #expect(settings.mode(at: start.addingTimeInterval(7200)) == .on)

        settings.isEnabled = false
        #expect(settings.mode(at: start) == .off)
    }

    @Test("The log trims old events and respects the cap")
    func append() {
        var log = HistoryEventLog()
        let old = HistoryEvent(date: start.addingTimeInterval(-8 * 86_400), kind: .userAway, title: "Old")
        log.append([old, HistoryEvent(date: start, kind: .userBack, title: "New")])
        #expect(log.events.count == 1)
        #expect(log.events.first?.title == "New")

        var many: [HistoryEvent] = []
        for index in 0...(HistoryEventLog.capacity) {
            many.append(
                HistoryEvent(date: start.addingTimeInterval(Double(index)), kind: .notification, title: "\(index)")
            )
        }
        log.append(many)
        #expect(log.events.count == HistoryEventLog.capacity)
        #expect(log.events.first?.title == "\(many.count - HistoryEventLog.capacity)")
    }

    @Test("The log survives a JSON round trip")
    func roundTrip() throws {
        let event = HistoryEvent(
            date: start,
            kind: .alertStarted,
            title: "Mac is getting hot",
            appName: "Example",
            value: "Thermal serious, 92 °C",
            key: "thermal_serious|system",
            notified: true
        )
        let data = try JSONEncoder().encode(HistoryEventLog(events: [event]))
        let restored = try JSONDecoder().decode(HistoryEventLog.self, from: data)
        #expect(restored.events == [event])
    }
}
