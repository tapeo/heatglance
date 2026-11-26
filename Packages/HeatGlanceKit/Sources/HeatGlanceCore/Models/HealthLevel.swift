import Foundation

public enum HealthLevel: Int, Comparable, Sendable, CaseIterable, Codable {
    case normal
    case elevated
    case critical

    public static func < (lhs: HealthLevel, rhs: HealthLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public static func worst(of levels: [HealthLevel]) -> HealthLevel {
        levels.max() ?? .normal
    }

    public var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .elevated:
            return "Elevated"
        case .critical:
            return "Critical"
        }
    }
}
