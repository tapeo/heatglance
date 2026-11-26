import Foundation

import HeatGlanceCore

#if canImport(Darwin)
public enum ThermalReader {
    public static func currentLevel() -> ThermalLevel {
        thermalLevel(for: ProcessInfo.processInfo.thermalState)
    }

    public static func thermalLevel(for state: ProcessInfo.ThermalState) -> ThermalLevel {
        switch state {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .serious
        }
    }
}
#endif
