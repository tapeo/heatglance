import Foundation

public struct ActiveRule: Sendable, Equatable, Identifiable {
    public let ruleID: String
    public let title: String
    public let level: HealthLevel
    public let isSystemWide: Bool
    public let targetKey: String
    public let since: Date

    public init(ruleID: String, title: String, level: HealthLevel, isSystemWide: Bool, targetKey: String, since: Date) {
        self.ruleID = ruleID
        self.title = title
        self.level = level
        self.isSystemWide = isSystemWide
        self.targetKey = targetKey
        self.since = since
    }

    public var id: String {
        "\(ruleID)|\(targetKey)"
    }

    public var groupID: String? {
        if isSystemWide {
            return nil
        }
        return targetKey
    }

    public static func isMoreUrgent(_ lhs: ActiveRule, _ rhs: ActiveRule) -> Bool {
        if lhs.level != rhs.level {
            return lhs.level > rhs.level
        }
        if lhs.since != rhs.since {
            return lhs.since < rhs.since
        }
        return lhs.id < rhs.id
    }
}
