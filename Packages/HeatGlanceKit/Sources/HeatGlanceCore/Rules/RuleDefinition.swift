import Foundation

public struct RuleDefinition: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let level: HealthLevel
    public let scope: RuleScope
    public let sustainSeconds: Double
    public let clearSeconds: Double
    public let condition: @Sendable (Sample, AppSettings) -> Bool

    public init(
        id: String,
        title: String,
        level: HealthLevel,
        scope: RuleScope,
        sustainSeconds: Double,
        clearSeconds: Double,
        condition: @escaping @Sendable (Sample, AppSettings) -> Bool
    ) {
        self.id = id
        self.title = title
        self.level = level
        self.scope = scope
        self.sustainSeconds = sustainSeconds
        self.clearSeconds = clearSeconds
        self.condition = condition
    }

    public static func == (lhs: RuleDefinition, rhs: RuleDefinition) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public func targetGroups(in sample: Sample) -> [ProcessGroup] {
        switch scope {
        case .system:
            return []
        case .applications:
            return sample.groups.filter(\.isApplication)
        case .processes:
            return sample.groups
        }
    }
}

public enum RuleScope: Sendable, Codable {
    case system
    case applications
    case processes
}

public struct Alert: Sendable, Identifiable {
    public let id: String
    public let ruleID: String
    public let title: String
    public let level: HealthLevel
    public let groupID: String?
    public let groupName: String?
    public let date: Date
    public let message: String

    public init(
        ruleID: String,
        title: String,
        level: HealthLevel,
        groupID: String?,
        groupName: String?,
        date: Date,
        message: String
    ) {
        self.ruleID = ruleID
        self.title = title
        self.level = level
        self.groupID = groupID
        self.groupName = groupName
        self.date = date
        if let groupName {
            self.message = "\(groupName): \(title.lowercasedFirstLetter())"
        } else {
            self.message = title
        }
        if let groupID {
            self.id = "\(ruleID)|\(groupID)"
        } else {
            self.id = ruleID
        }
    }
}

extension String {
    func lowercasedFirstLetter() -> String {
        guard let first = first else {
            return self
        }
        return first.lowercased() + dropFirst()
    }
}
