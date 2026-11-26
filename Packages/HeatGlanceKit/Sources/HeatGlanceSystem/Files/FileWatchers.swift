import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)
import AppKit

public enum FolderGrowth {
    public static func measure(_ folders: [WatchedFolder], excluded: ExcludedFolders, now: Date = Date()) -> [FolderMeasurement] {
        let home = NSHomeDirectory()
        var results: [FolderMeasurement] = []
        for folder in folders {
            let path = home + "/" + folder.relativePath
            guard !excluded.contains(path), FileManager.default.fileExists(atPath: path) else {
                continue
            }
            if let size = CacheSizer.sizeOnDisk(ofPath: path, excluding: excluded.inside(path)) {
                results.append(FolderMeasurement(path: path, bytes: size, date: now))
            }
        }
        return results
    }
}

public enum LargeFileWatch {
    public static func scan(minimumBytes: Int64, folders: [WatchedFolder], excluded: ExcludedFolders) -> [URL] {
        let home = NSHomeDirectory()
        var results: [URL] = []
        for folder in folders where folder.scansLargeFiles {
            let url = URL(fileURLWithPath: home + "/" + folder.relativePath)
            guard !excluded.contains(url.path), FileManager.default.fileExists(atPath: url.path) else {
                continue
            }
            results.append(contentsOf: LargeFileScanner.filesLargerThan(
                bytes: minimumBytes,
                in: url,
                limit: 20,
                excluding: excluded.inside(url.path)
            ))
        }
        return results.sorted { lhs, rhs in
            let left = (try? lhs.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize) ?? 0
            let right = (try? rhs.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize) ?? 0
            return left > right
        }
    }
}
#endif
