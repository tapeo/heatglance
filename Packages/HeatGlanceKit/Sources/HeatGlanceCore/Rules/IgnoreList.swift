import Foundation

public struct IgnoreEntry: Sendable, Codable, Identifiable, Hashable {
    public let id: String
    public let kind: Kind
    public let value: String
    public let label: String
    public let expiresAt: Date?

    public enum Kind: String, Sendable, Codable {
        case rule
        case group
        case folder
        case orphan
    }

    public init(id: String = UUID().uuidString, kind: Kind, value: String, label: String, expiresAt: Date?) {
        self.id = id
        self.kind = kind
        self.value = value
        self.label = label
        self.expiresAt = expiresAt
    }

    public func isActive(at date: Date) -> Bool {
        guard let expiresAt else {
            return true
        }
        return expiresAt > date
    }
}

public struct IgnoreList: Sendable, Codable {
    public private(set) var entries: [IgnoreEntry]

    public init(entries: [IgnoreEntry] = []) {
        self.entries = entries
    }

    public func activeKeys(at date: Date) -> Set<String> {
        Set(entries.filter { $0.kind == .rule || $0.kind == .group }.filter { $0.isActive(at: date) }.map(\.value))
    }

    public func isIgnored(key: String, at date: Date) -> Bool {
        entries.contains { $0.value == key && $0.isActive(at: date) }
    }

    public mutating func add(_ entry: IgnoreEntry) {
        entries.removeAll { $0.kind == entry.kind && $0.value == entry.value && $0.isActive(at: Date()) }
        entries.append(entry)
        prune(at: Date())
    }

    public mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
    }

    public mutating func prune(at date: Date) {
        entries.removeAll { !$0.isActive(at: date) }
    }
}

public struct Cooldown: Sendable, Codable {
    public private(set) var lastAlertAt: [String: Date]

    public init(lastAlertAt: [String: Date] = [:]) {
        self.lastAlertAt = lastAlertAt
    }

    public func allows(key: String, now: Date, window: TimeInterval, escalated: Bool) -> Bool {
        guard !escalated else {
            return true
        }
        guard let last = lastAlertAt[key] else {
            return true
        }
        return now.timeIntervalSince(last) >= window
    }

    public mutating func record(key: String, now: Date) {
        lastAlertAt[key] = now
    }
}
