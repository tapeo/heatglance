import Foundation

#if canImport(AppKit) && canImport(Darwin)
import Darwin

public struct CommandResult: Sendable {
    public let status: Int32
    public let output: String
    public let timedOut: Bool

    public var succeeded: Bool {
        status == 0 && !timedOut
    }
}

public enum CommandRunner {
    public static func run(
        _ executable: String,
        arguments: [String],
        timeout: TimeInterval,
        includeErrors: Bool = false
    ) -> CommandResult? {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("heatglance-\(UUID().uuidString).out")
        guard FileManager.default.createFile(atPath: outputURL.path, contents: nil),
              let outputHandle = try? FileHandle(forWritingTo: outputURL)
        else {
            return nil
        }
        defer {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.environment = environment()
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory())
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputHandle
        if includeErrors {
            process.standardError = outputHandle
        } else {
            process.standardError = FileHandle.nullDevice
        }

        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            finished.signal()
        }
        do {
            try process.run()
        } catch {
            return nil
        }

        var timedOut = false
        if finished.wait(timeout: .now() + timeout) == .timedOut {
            timedOut = true
            process.terminate()
            if finished.wait(timeout: .now() + 5) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                finished.wait()
            }
        }

        let data = (try? Data(contentsOf: outputURL)) ?? Data()
        return CommandResult(status: process.terminationStatus, output: String(decoding: data, as: UTF8.self), timedOut: timedOut)
    }

    static func environment() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let current = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        environment["PATH"] = (CommandLocator.searchPaths + [current]).joined(separator: ":")
        return environment
    }
}
#endif
