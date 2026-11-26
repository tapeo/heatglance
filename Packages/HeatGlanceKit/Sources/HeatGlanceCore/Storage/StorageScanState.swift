import Foundation

public enum FolderProtection: String, Sendable, Codable {
    case none
    case fullDiskAccess
}

public struct WatchedFolder: Sendable, Equatable {
    public let relativePath: String
    public let protection: FolderProtection
    public let scansLargeFiles: Bool

    public init(relativePath: String, protection: FolderProtection, scansLargeFiles: Bool) {
        self.relativePath = relativePath
        self.protection = protection
        self.scansLargeFiles = scansLargeFiles
    }
}

public enum WatchedFolders {
    public static let all: [WatchedFolder] = [
        WatchedFolder(relativePath: "Desktop", protection: .fullDiskAccess, scansLargeFiles: true),
        WatchedFolder(relativePath: "Documents", protection: .fullDiskAccess, scansLargeFiles: true),
        WatchedFolder(relativePath: "Downloads", protection: .fullDiskAccess, scansLargeFiles: true),
        WatchedFolder(relativePath: "Movies", protection: .fullDiskAccess, scansLargeFiles: true),
        WatchedFolder(relativePath: "Pictures", protection: .fullDiskAccess, scansLargeFiles: false),
        WatchedFolder(relativePath: "Music", protection: .fullDiskAccess, scansLargeFiles: false),
        WatchedFolder(relativePath: "Library/Caches", protection: .fullDiskAccess, scansLargeFiles: false),
        WatchedFolder(relativePath: "Library/Developer", protection: .none, scansLargeFiles: false),
    ]

    public static func allowed(hasFullDiskAccess: Bool) -> [WatchedFolder] {
        all.filter { folder in
            folder.protection == .none || hasFullDiskAccess
        }
    }
}

public struct FolderMeasurement: Sendable, Codable, Equatable {
    public let path: String
    public let bytes: Int64
    public let date: Date

    public init(path: String, bytes: Int64, date: Date) {
        self.path = path
        self.bytes = bytes
        self.date = date
    }
}

public struct StorageScanState: Sendable, Codable, Equatable {
    public static let fileScanInterval: TimeInterval = 1800
    public static let folderMeasureInterval: TimeInterval = 86_400
    public static let notifiedLimit = 500

    public var lastFileScanAt: Date?
    public var lastFolderMeasureAt: Date?
    public var notifiedLargeFiles: [String]
    public var folderMeasurements: [FolderMeasurement]

    public init(
        lastFileScanAt: Date? = nil,
        lastFolderMeasureAt: Date? = nil,
        notifiedLargeFiles: [String] = [],
        folderMeasurements: [FolderMeasurement] = []
    ) {
        self.lastFileScanAt = lastFileScanAt
        self.lastFolderMeasureAt = lastFolderMeasureAt
        self.notifiedLargeFiles = notifiedLargeFiles
        self.folderMeasurements = folderMeasurements
    }

    public func isFileScanDue(at now: Date) -> Bool {
        Self.isDue(last: lastFileScanAt, now: now, interval: Self.fileScanInterval)
    }

    public func isFolderMeasureDue(at now: Date) -> Bool {
        Self.isDue(last: lastFolderMeasureAt, now: now, interval: Self.folderMeasureInterval)
    }

    public mutating func recordLargeFiles(_ paths: [String]) -> [String] {
        let fresh = paths.filter { !notifiedLargeFiles.contains($0) }
        notifiedLargeFiles.append(contentsOf: fresh)
        if notifiedLargeFiles.count > Self.notifiedLimit {
            notifiedLargeFiles.removeFirst(notifiedLargeFiles.count - Self.notifiedLimit)
        }
        return fresh
    }

    public static func isDue(last: Date?, now: Date, interval: TimeInterval) -> Bool {
        guard let last else {
            return true
        }
        if last > now {
            return true
        }
        return now.timeIntervalSince(last) >= interval
    }

    public static func growth(previous: [FolderMeasurement], current: [FolderMeasurement], minimumBytes: Int64) -> [FolderMeasurement] {
        var changes: [FolderMeasurement] = []
        for now in current {
            guard let before = previous.first(where: { $0.path == now.path }) else {
                continue
            }
            let delta = now.bytes - before.bytes
            if delta >= minimumBytes {
                changes.append(FolderMeasurement(path: now.path, bytes: delta, date: now.date))
            }
        }
        return changes.sorted { $0.bytes > $1.bytes }
    }
}
