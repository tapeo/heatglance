import Foundation

#if canImport(Darwin)
import Darwin

import HeatGlanceCore

public enum MemoryReader {
    public static func pressureLevel() -> MemoryPressureLevel {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &value, &size, nil, 0)
        guard result == 0 else {
            return .normal
        }
        if value >= 4 {
            return .critical
        }
        if value >= 2 {
            return .warning
        }
        return .normal
    }

    public static func swapUsedBytes() -> UInt64 {
        var usage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &usage, &size, nil, 0)
        guard result == 0 else {
            return 0
        }
        return usage.xsu_used
    }

    public static func physicalMemoryBytes() -> UInt64 {
        ProcessInfo.processInfo.physicalMemory
    }
}

public final class MemoryPressureObserver: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.heatglance.memorypressure")
    private var source: DispatchSourceMemoryPressure?

    public init() {}

    public func start(handler: @escaping @Sendable (MemoryPressureLevel) -> Void) {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )
        source.setEventHandler {
            let level: MemoryPressureLevel
            let events = source.data
            if events.contains(.critical) {
                level = .critical
            } else if events.contains(.warning) {
                level = .warning
            } else {
                level = .normal
            }
            handler(level)
        }
        self.source = source
        source.activate()
    }

    public func stop() {
        source?.cancel()
        source = nil
    }
}
#endif
