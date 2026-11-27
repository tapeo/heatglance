import Foundation

public enum HistoryEventKind: String, Codable, CaseIterable, Sendable {
    case alertStarted
    case alertEnded
    case notification
    case appPausedByProtection
    case appResumedByProtection
    case protectionOff
    case protectionSnoozed
    case protectionOn
    case manualSuspend
    case manualResume
    case manualQuit
    case manualForceQuit
    case userAway
    case userBack

    public var category: HistoryEventCategory {
        switch self {
        case .alertStarted, .alertEnded:
            return .alerts
        case .notification:
            return .notifications
        case .appPausedByProtection, .appResumedByProtection, .protectionOff, .protectionSnoozed, .protectionOn:
            return .protection
        case .manualSuspend, .manualResume, .manualQuit, .manualForceQuit:
            return .actions
        case .userAway, .userBack:
            return .presence
        }
    }

    public var title: String {
        switch self {
        case .alertStarted:
            return "Alert"
        case .alertEnded:
            return "Alert cleared"
        case .notification:
            return "Notification"
        case .appPausedByProtection:
            return "App paused"
        case .appResumedByProtection:
            return "App resumed"
        case .protectionOff:
            return "Protection off"
        case .protectionSnoozed:
            return "Protection paused"
        case .protectionOn:
            return "Protection on"
        case .manualSuspend:
            return "Suspended"
        case .manualResume:
            return "Resumed"
        case .manualQuit:
            return "Quit"
        case .manualForceQuit:
            return "Force quit"
        case .userAway:
            return "Away"
        case .userBack:
            return "Back"
        }
    }
}

public enum HistoryEventCategory: String, CaseIterable, Identifiable, Sendable {
    case alerts
    case notifications
    case protection
    case actions
    case presence

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .alerts:
            return "Alerts"
        case .notifications:
            return "Notifications"
        case .protection:
            return "Protection"
        case .actions:
            return "Your actions"
        case .presence:
            return "Presence"
        }
    }
}

public struct HistoryEvent: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let kind: HistoryEventKind
    public let title: String
    public let appName: String?
    public let value: String?
    public let detail: String?
    public let key: String?
    public let notified: Bool?

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        kind: HistoryEventKind,
        title: String,
        appName: String? = nil,
        value: String? = nil,
        detail: String? = nil,
        key: String? = nil,
        notified: Bool? = nil
    ) {
        self.id = id
        self.date = date
        self.kind = kind
        self.title = title
        self.appName = appName
        self.value = value
        self.detail = detail
        self.key = key
        self.notified = notified
    }
}

public struct HistoryEventLog: Sendable, Codable {
    public static let retention: TimeInterval = 7 * 86_400
    public static let capacity = 5000

    public private(set) var events: [HistoryEvent]

    public init(events: [HistoryEvent] = []) {
        self.events = events
    }

    public mutating func append(_ newEvents: [HistoryEvent]) {
        guard !newEvents.isEmpty else {
            return
        }
        events.append(contentsOf: newEvents)
        events.sort { $0.date < $1.date }
        guard let newest = events.last?.date else {
            return
        }
        let cutoff = newest.addingTimeInterval(-Self.retention)
        if let first = events.first, first.date < cutoff {
            events.removeAll { $0.date < cutoff }
        }
        if events.count > Self.capacity {
            events.removeFirst(events.count - Self.capacity)
        }
    }

    public func events(since date: Date) -> [HistoryEvent] {
        events.filter { $0.date >= date }
    }

    public func events(in interval: DateInterval) -> [HistoryEvent] {
        events.filter { interval.contains($0.date) }
    }

    public func alertEvents(
        previous: [ActiveRule],
        current: [ActiveRule],
        sample: Sample,
        notifiedKeys: Set<String>
    ) -> [HistoryEvent] {
        let previousIDs = Set(previous.map(\.id))
        let currentIDs = Set(current.map(\.id))
        var newEvents: [HistoryEvent] = []

        for rule in current where !previousIDs.contains(rule.id) {
            let alert = HistoryEventValue.alert(ruleID: rule.ruleID, groupID: rule.groupID, sample: sample)
            let notified: Bool?
            if notifiedKeys.contains(rule.id) {
                notified = true
            } else {
                notified = nil
            }
            newEvents.append(
                HistoryEvent(
                    date: sample.date,
                    kind: .alertStarted,
                    title: rule.title,
                    appName: alert.appName,
                    value: alert.value,
                    key: rule.id,
                    notified: notified
                )
            )
        }

        for rule in previous where !currentIDs.contains(rule.id) {
            let lasted = HistoryEventValue.duration(sample.date.timeIntervalSince(rule.since))
            let started = events.last { $0.kind == .alertStarted && $0.key == rule.id }
            newEvents.append(
                HistoryEvent(
                    date: sample.date,
                    kind: .alertEnded,
                    title: rule.title,
                    appName: started?.appName,
                    value: "Lasted \(lasted)",
                    key: rule.id
                )
            )
        }

        return newEvents
    }

    public func presenceEvent(previous: Presence, current: Presence, at date: Date, notified: Bool) -> HistoryEvent? {
        guard previous.isAway != current.isAway else {
            return nil
        }

        if current.isAway {
            return HistoryEvent(date: date, kind: .userAway, title: "You left the Mac")
        }

        let away: String?
        if let lastAway = events.last(where: { $0.kind == .userAway }) {
            away = "Away \(HistoryEventValue.duration(date.timeIntervalSince(lastAway.date)))"
        } else {
            away = nil
        }

        let wasNotified: Bool?
        if notified {
            wasNotified = true
        } else {
            wasNotified = nil
        }

        return HistoryEvent(
            date: date,
            kind: .userBack,
            title: "You came back",
            value: away,
            notified: wasNotified
        )
    }

    public func protectionEvent(
        previous: ProtectionMode,
        current: ProtectionMode,
        at now: Date,
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> HistoryEvent? {
        guard previous != current else {
            return nil
        }

        switch current {
        case .off:
            return HistoryEvent(date: now, kind: .protectionOff, title: "Protection turned off")
        case let .paused(until):
            let value = Self.pauseValue(until: until, now: now, calendar: calendar, timeZone: timeZone)
            return HistoryEvent(date: now, kind: .protectionSnoozed, title: "Protection paused", value: value)
        case .on:
            if case let .paused(until) = previous, until <= now {
                return HistoryEvent(date: until, kind: .protectionOn, title: "Protection resumed", value: "Pause ended")
            }
            return HistoryEvent(date: now, kind: .protectionOn, title: "Protection turned on")
        }
    }

    private static func pauseValue(until: Date, now: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        if calendar.isDate(until, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "MMM d, HH:mm"
        }
        return "Until \(formatter.string(from: until))"
    }
}
