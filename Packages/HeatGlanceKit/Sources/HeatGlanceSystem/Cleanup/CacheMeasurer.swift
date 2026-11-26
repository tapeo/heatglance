import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)

public enum CacheMeasurer {
    public static func measure(_ source: CacheSizeSource) async -> CacheMeasurement {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(returning: measureNow(source))
            }
        }
    }

    public static func measureNow(_ source: CacheSizeSource) -> CacheMeasurement {
        switch source {
        case let .folder(path):
            return CacheMeasurement.of(bytes: CacheSizer.sizeOnDisk(ofPath: path), source: source)
        case .unavailableSimulators:
            return simulators()
        case .homebrewCache:
            return toolFolder(tool: "brew", path: "~/Library/Caches/Homebrew", source: source)
        case .npmCache:
            return toolFolder(tool: "npm", path: "~/.npm/_cacache", source: source)
        case .pnpmStore:
            return pnpmStore()
        case .dockerImages:
            return dockerImages()
        }
    }

    private static func toolFolder(tool: String, path: String, source: CacheSizeSource) -> CacheMeasurement {
        guard CommandLocator.locate(tool) != nil else {
            return .notInstalled
        }
        return CacheMeasurement.of(bytes: CacheSizer.sizeOnDisk(ofPath: path), source: source)
    }

    private static func simulators() -> CacheMeasurement {
        guard let select = CommandRunner.run("/usr/bin/xcode-select", arguments: ["-p"], timeout: 5), select.succeeded else {
            return .notInstalled
        }
        guard let list = CommandRunner.run("/usr/bin/xcrun", arguments: ["simctl", "list", "devices", "-j"], timeout: 30), list.succeeded else {
            return .notInstalled
        }
        let root = CacheSizer.expand("~/Library/Developer/CoreSimulator/Devices")
        guard let folders = SimulatorList.unavailableDeviceFolders(json: Data(list.output.utf8), devicesRoot: root) else {
            return .unknown
        }
        let total = folders.compactMap { CacheSizer.sizeOnDisk(ofPath: $0) }.reduce(0, +)
        return CacheMeasurement.of(bytes: total, source: .unavailableSimulators)
    }

    private static func pnpmStore() -> CacheMeasurement {
        guard let tool = CommandLocator.locate("pnpm") else {
            return .notInstalled
        }
        var path = "~/Library/pnpm/store"
        if let result = CommandRunner.run(tool, arguments: ["store", "path"], timeout: 15), result.succeeded {
            let reported = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if reported.hasPrefix("/") {
                path = reported
            }
        }
        return CacheMeasurement.of(bytes: CacheSizer.sizeOnDisk(ofPath: path), source: .pnpmStore)
    }

    private static func dockerImages() -> CacheMeasurement {
        guard let tool = CommandLocator.locate("docker") else {
            return .notInstalled
        }
        let arguments = ["system", "df", "--format", "{{.Type}}|{{.Reclaimable}}"]
        guard let result = CommandRunner.run(tool, arguments: arguments, timeout: 15) else {
            return .unknown
        }
        guard result.succeeded else {
            return .notRunning
        }
        guard let bytes = DockerDiskUsage.reclaimableImageBytes(output: result.output) else {
            return .unknown
        }
        return CacheMeasurement.of(bytes: bytes, source: .dockerImages)
    }
}
#endif
