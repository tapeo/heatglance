import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)
import AppKit

public enum CacheSizer {
    public static func sizeOnDisk(ofPath path: String) -> Int64? {
        let url = URL(fileURLWithPath: expand(path))
        guard FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        let keys: Set<URLResourceKey> = [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            return nil
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
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
    private static let searchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]

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
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(decoding: data, as: UTF8.self)
                if process.terminationStatus == 0 {
                    return Result(succeeded: true, message: output.isEmpty ? "Done" : output)
                }
                return Result(succeeded: false, message: output.isEmpty ? "Failed with status \(process.terminationStatus)" : output)
            } catch {
                return Result(succeeded: false, message: error.localizedDescription)
            }
        }
    }
}

public enum LargeFileScanner {
    public static func filesLargerThan(bytes: Int64, in root: URL, limit: Int = 50) -> [URL] {
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
