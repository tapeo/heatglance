import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)
import AppKit
import Darwin

public enum OrphanFinder {
    public static func candidates(groups: [ProcessGroup], currentUserID: UInt32 = getuid()) -> [OrphanCandidate] {
        let classifier = OrphanClassifier()
        let runningBundlePaths = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.path })
        var results: [OrphanCandidate] = []
        for group in groups {
            guard let member = group.members.first else {
                continue
            }
            let parentIsLaunchd = member.parentPID == 1
            let appIsRunning = AppBundlePath.isRunning(
                executablePath: member.executablePath,
                runningBundlePaths: runningBundlePaths
            )
            let isLoginItem = member.executablePath?.contains("/Contents/Library/LoginItems/") == true
            let input = OrphanClassifier.Input(
                group: group,
                parentIsLaunchd: parentIsLaunchd,
                bundleAppIsRunning: appIsRunning,
                isLoginItem: isLoginItem
            )
            if let candidate = classifier.classify(input) {
                results.append(candidate)
            }
        }
        return results.sorted { $0.cpuPercent > $1.cpuPercent }
    }
}

public enum LoginItemManager {
    public static var isEnabled: Bool {
        get { false }
    }
}

public enum TimeMachineSnapshots {
    public struct Snapshot: Sendable, Identifiable {
        public let date: String
        public var id: String { date }
    }

    public static func list() -> [Snapshot] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["listlocalsnapshots", "/"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(decoding: data, as: UTF8.self)
            return output
                .split(separator: "\n")
                .compactMap { line -> Snapshot? in
                    guard let range = line.range(of: "com.apple.TimeMachine.") else {
                        return nil
                    }
                    var value = String(line[range.upperBound...])
                    if value.hasSuffix(".local") {
                        value = String(value.dropLast(6))
                    }
                    return Snapshot(date: value)
                }
        } catch {
            return []
        }
    }

    public static func delete(date: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        process.arguments = ["deletelocalsnapshots", date]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}
#endif
