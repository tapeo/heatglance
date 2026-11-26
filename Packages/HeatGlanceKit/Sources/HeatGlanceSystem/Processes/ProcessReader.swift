import Foundation

#if canImport(AppKit) && canImport(Darwin)
import AppKit
import Darwin

public actor ProcessReader {
    private struct UsageSample {
        let micros: UInt64
        let footprint: UInt64
        let written: UInt64
        let date: Date
    }

    private struct GroupAccumulator {
        var name: String
        var bundleIdentifier: String?
        var members: [ProcessSnapshot] = []
    }

    private var previousUsage: [ProcessIdentity: UsageSample] = [:]

    public init() {}

    public func readGroups(currentUserID: UInt32 = getuid(), now: Date = Date()) -> [ProcessGroup] {
        let raw = listProcesses(now: now, currentUserID: currentUserID)
        var groups: [String: GroupAccumulator] = [:]

        for process in raw {
            let key: String
            let app = applicationInfo(for: process.identity.pid)
            if let app {
                key = app.bundleIdentifier
            } else {
                key = process.executablePath ?? process.name
            }
            var accumulator = groups[key] ?? GroupAccumulator(
                name: app?.name ?? process.name,
                bundleIdentifier: app?.bundleIdentifier
            )
            accumulator.members.append(process)
            groups[key] = accumulator
        }

        return groups.map { key, accumulator in
            ProcessGroup(
                id: key,
                displayName: accumulator.name,
                bundleIdentifier: accumulator.bundleIdentifier,
                members: accumulator.members.sorted { $0.cpuPercent > $1.cpuPercent }
            )
        }
    }

    public func identityExists(_ identity: ProcessIdentity) -> Bool {
        ProcessIdentityVerifier.isAlive(identity)
    }

    private func applicationInfo(for pid: Int32) -> (name: String, bundleIdentifier: String)? {
        guard let app = NSRunningApplication(processIdentifier: pid),
              let bundleID = app.bundleIdentifier
        else {
            return nil
        }
        return (app.localizedName ?? bundleID, bundleID)
    }

    private func listProcesses(now: Date, currentUserID: UInt32) -> [ProcessSnapshot] {
        var snapshots: [ProcessSnapshot] = []
        var seen: Set<ProcessIdentity> = []
        for pid in allPIDs() where pid > 0 {
            guard let snapshot = snapshot(for: pid, now: now, currentUserID: currentUserID) else {
                continue
            }
            snapshots.append(snapshot)
            seen.insert(snapshot.identity)
        }
        previousUsage = previousUsage.filter { seen.contains($0.key) }
        return snapshots
    }

    private func allPIDs() -> [pid_t] {
        var capacity = 4096
        while capacity <= 65_536 {
            var pids = [pid_t](repeating: 0, count: capacity)
            let bytes = pids.withUnsafeMutableBytes { buffer -> Int in
                proc_listallpids(buffer.baseAddress, Int32(buffer.count * MemoryLayout<pid_t>.stride))
            }
            guard bytes > 0 else {
                return []
            }
            let count = bytes / MemoryLayout<pid_t>.stride
            if count < capacity {
                return Array(pids.prefix(count))
            }
            capacity *= 2
        }
        return []
    }

    private func snapshot(for pid: pid_t, now: Date, currentUserID: UInt32) -> ProcessSnapshot? {
        var info = proc_bsdinfo()
        let infoSize = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(infoSize))
        guard result == Int32(infoSize), info.pbi_uid == currentUserID else {
            return nil
        }

        let path = executablePath(for: pid)
        let name = String(decoding: withUnsafeBytes(of: info.pbi_comm) { $0.prefix { $0 != 0 } }, as: UTF8.self)
        let resolvedName = name.isEmpty ? ((path as NSString?)?.lastPathComponent ?? "pid \(pid)") : name

        var usage = rusage_info_v4()
        let usageResult = withUnsafeMutablePointer(to: &usage) { pointer -> Int32 in
            pointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }

        var cpuMicros: UInt64 = 0
        var footprint: UInt64 = 0
        var written: UInt64 = 0
        if usageResult == 0 {
            cpuMicros = machMicros(fromTicks: usage.ri_user_time + usage.ri_system_time)
            footprint = usage.ri_phys_footprint
            written = usage.ri_diskio_byteswritten
        }

        let startTime = Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
        let identity = ProcessIdentity(pid: pid, startTime: startTime)
        let previous = previousUsage[identity]
        previousUsage[identity] = UsageSample(micros: cpuMicros, footprint: footprint, written: written, date: now)

        let cpuPercent: Double
        if let previous, cpuMicros >= previous.micros {
            let elapsed = now.timeIntervalSince(previous.date)
            if elapsed > 0.2 {
                let deltaSeconds = Double(cpuMicros - previous.micros) / 1_000_000
                cpuPercent = max(deltaSeconds / elapsed * 100, 0)
            } else {
                cpuPercent = 0
            }
        } else {
            cpuPercent = 0
        }

        return ProcessSnapshot(
            identity: identity,
            parentPID: Int32(info.pbi_ppid),
            userID: info.pbi_uid,
            name: resolvedName,
            executablePath: path,
            cpuPercent: cpuPercent,
            footprintBytes: footprint,
            bytesWritten: written
        )
    }

    private func machMicros(fromTicks ticks: UInt64) -> UInt64 {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        let nanoseconds = ticks * UInt64(info.numer) / UInt64(info.denom)
        return nanoseconds / 1000
    }

    private func executablePath(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else {
            return nil
        }
        return String(cString: buffer)
    }
}

public enum ProcessIdentityVerifier {
    public static func isAlive(_ identity: ProcessIdentity) -> Bool {
        guard let start = startTime(for: identity.pid) else {
            return false
        }
        return start == identity.startTime
    }

    public static func startTime(for pid: Int32) -> Date? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.size
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, Int32(size))
        guard result == Int32(size) else {
            return nil
        }
        return Date(timeIntervalSince1970: TimeInterval(info.pbi_start_tvsec))
    }
}
#endif
