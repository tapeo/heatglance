import Foundation

#if canImport(Darwin)
public struct DiskState: Sendable {
    public let availableBytes: Int64
    public let totalBytes: Int64

    public init(availableBytes: Int64, totalBytes: Int64) {
        self.availableBytes = availableBytes
        self.totalBytes = totalBytes
    }

    public var usedBytes: Int64 {
        max(totalBytes - availableBytes, 0)
    }
}

public enum DiskReader {
    public static func state() -> DiskState {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let keys: Set<URLResourceKey> = [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey,
        ]
        guard let values = try? home.resourceValues(forKeys: keys) else {
            return DiskState(availableBytes: 0, totalBytes: 0)
        }
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(values.volumeTotalCapacity ?? 0)
        return DiskState(availableBytes: available, totalBytes: total)
    }
}
#endif
