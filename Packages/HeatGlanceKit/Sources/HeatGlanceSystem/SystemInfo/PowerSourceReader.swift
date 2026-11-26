import Foundation

#if canImport(Darwin)
import IOKit.ps

import HeatGlanceCore

public struct PowerState: Sendable {
    public let isOnACPower: Bool
    public let isCharging: Bool
    public let batteryTemperatureCelsius: Double?

    public init(isOnACPower: Bool, isCharging: Bool, batteryTemperatureCelsius: Double?) {
        self.isOnACPower = isOnACPower
        self.isCharging = isCharging
        self.batteryTemperatureCelsius = batteryTemperatureCelsius
    }

    public static let unknown = PowerState(
        isOnACPower: true,
        isCharging: false,
        batteryTemperatureCelsius: nil
    )
}

public enum PowerSourceReader {
    public static func read() -> PowerState {
        guard let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String?
        else {
            return .unknown
        }
        let onAC = type == kIOPSACPowerValue
        var charging = false
        if let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
            for source in sources {
                guard let description = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any] else {
                    continue
                }
                if let isCharging = description[kIOPSIsChargingKey] as? Bool {
                    charging = isCharging
                }
            }
        }
        return PowerState(
            isOnACPower: onAC,
            isCharging: charging,
            batteryTemperatureCelsius: BatteryReader.temperatureCelsius()
        )
    }
}

public enum BatteryReader {
    public static func temperatureCelsius() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else {
            return nil
        }
        defer { IOObjectRelease(service) }
        guard let raw = IORegistryEntryCreateCFProperty(
            service,
            "Temperature" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? Int else {
            return nil
        }
        return Double(raw) / 100
    }
}
#endif
