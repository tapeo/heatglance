import Foundation

public enum ThermalLevel: Int, Comparable, Sendable, CaseIterable, Codable {
    case nominal
    case fair
    case serious
    case critical

    public static func < (lhs: ThermalLevel, rhs: ThermalLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var healthLevel: HealthLevel {
        switch self {
        case .nominal, .fair:
            return .normal
        case .serious:
            return .elevated
        case .critical:
            return .critical
        }
    }

    public var title: String {
        switch self {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        }
    }
}

public enum MemoryPressureLevel: Int, Comparable, Sendable, CaseIterable, Codable {
    case normal
    case warning
    case critical

    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var healthLevel: HealthLevel {
        switch self {
        case .normal:
            return .normal
        case .warning:
            return .elevated
        case .critical:
            return .critical
        }
    }

    public var title: String {
        switch self {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .critical:
            return "Critical"
        }
    }
}
