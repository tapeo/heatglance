import Foundation

#if canImport(Darwin)
import AppKit
import IOKit
import IOKit.pwr_mgt

import HeatGlanceCore

public enum SleepAssertionsReader {
    public static func processes(keepingAwake type: String? = nil) -> [String] {
        var assertionsByProcess: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&assertionsByProcess)
        guard result == kIOReturnSuccess, let dictionary = assertionsByProcess?.takeRetainedValue() as? [String: [[String: Any]]] else {
            return []
        }
        var names: [String] = []
        for (pidString, assertions) in dictionary {
            let matching: Bool
            if let type {
                matching = assertions.contains { assertion in
                    (assertion[kIOPMAssertionTypeKey] as? String) == type
                }
            } else {
                matching = !assertions.isEmpty
            }
            guard matching else {
                continue
            }
            let name = processName(for: pidString)
            if let name, !names.contains(name) {
                names.append(name)
            }
        }
        return names.sorted()
    }

    public static func isDisplaySleepPrevented() -> Bool {
        !processes(keepingAwake: kIOPMAssertionTypePreventUserIdleDisplaySleep as String).isEmpty
    }

    public static func isSystemSleepPrevented() -> Bool {
        !processes(keepingAwake: kIOPMAssertionTypePreventUserIdleSystemSleep as String).isEmpty
    }

    private static func processName(for pidString: String) -> String? {
        guard let pid = Int32(pidString) else {
            return nil
        }
        guard let app = NSRunningApplication(processIdentifier: pid) else {
            var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
            guard length > 0 else {
                return "pid \(pid)"
            }
            return (String(cString: buffer) as NSString).lastPathComponent
        }
        return app.localizedName
    }
}

public enum UptimeReader {
    public static func bootDate() -> Date? {
        var value = timeval()
        var size = MemoryLayout<timeval>.size
        let result = sysctlbyname("kern.boottime", &value, &size, nil, 0)
        guard result == 0 else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(value.tv_sec))
    }

    public static func uptimeDays() -> Double? {
        guard let boot = bootDate() else {
            return nil
        }
        return Date().timeIntervalSince(boot) / 86_400
    }
}
#endif
