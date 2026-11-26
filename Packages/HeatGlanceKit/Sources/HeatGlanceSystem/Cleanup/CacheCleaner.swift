import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)
import AppKit

public enum CacheSizer {
    public static func sizeOnDisk(ofPath path: String, excluding excludedPaths: [String] = []) -> Int64? {
        let url = URL(fileURLWithPath: expand(path))
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if excludedPaths.contains(fileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    public static func expand(_ path: String) -> String {
        (path as NSString).expandingTildeInPath
    }
}

public enum CommandLocator {
    public static var searchPaths: [String] {
        let home = NSHomeDirectory()
        return ["/opt/homebrew/bin", "/usr/local/bin", home + "/.docker/bin", home + "/Library/pnpm", "/usr/bin"]
    }

    public static func locate(_ name: String) -> String? {
        if name.hasPrefix("/") {
            return FileManager.default.isExecutableFile(atPath: name) ? name : nil
        }
        for directory in searchPaths {
            let candidate = directory + "/" + name
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

public enum CacheCleaner {
    public struct Result: Sendable {
        public let succeeded: Bool
        public let message: String
    }

    public static func clean(_ item: CacheItem) -> Result {
        switch item.method {
        case .trash:
            guard let path = item.path else {
                return Result(succeeded: false, message: "No path")
            }
            let url = URL(fileURLWithPath: CacheSizer.expand(path))
            guard FileManager.default.fileExists(atPath: url.path) else {
                return Result(succeeded: false, message: "Not present")
            }
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                return Result(succeeded: true, message: "Moved to the Trash")
            } catch {
                return Result(succeeded: false, message: error.localizedDescription)
            }
        case let .command(executable, arguments):
            guard let tool = CommandLocator.locate(executable) else {
                return Result(succeeded: false, message: "\(executable) is not installed")
            }
            guard let result = CommandRunner.run(tool, arguments: arguments, timeout: 600, includeErrors: true) else {
                return Result(succeeded: false, message: "Could not start \(executable)")
            }
            return Result(succeeded: result.succeeded, message: message(for: result))
        }
    }

    private static func message(for result: CommandResult) -> String {
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.timedOut {
            return "Stopped after 10 minutes"
        }
        if !output.isEmpty {
            return output
        }
        if result.succeeded {
            return "Done"
        }
        return "Failed with status \(result.status)"
    }
}

public enum LargeFileScanner {
    public static func filesLargerThan(bytes: Int64, in root: URL, limit: Int = 50, excluding excludedPaths: [String] = []) -> [URL] {
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return []
        }
        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if excludedPaths.contains(fileURL.path) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? fileURL.resourceValues(forKeys: keys), values.isRegularFile == true else {
                continue
            }
            let size = Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
            if size >= bytes {
                results.append(fileURL)
                if results.count >= limit {
                    break
                }
            }
        }
        return results.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0
            let right = (try? rhs.resourceValues(forKeys: keys).totalFileAllocatedSize) ?? 0
            return left > right
        }
    }
}
#endif
