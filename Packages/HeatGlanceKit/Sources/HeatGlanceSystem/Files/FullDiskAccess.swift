import Foundation

#if canImport(AppKit) && canImport(Darwin)
import Darwin

public enum FullDiskAccess {
    public static func isGranted() -> Bool {
        probePaths.contains { canOpen($0) }
    }

    static var probePaths: [String] {
        [
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
            "/Library/Application Support/com.apple.TCC/TCC.db",
        ]
    }

    private static func canOpen(_ path: String) -> Bool {
        let descriptor = open(path, O_RDONLY)
        guard descriptor >= 0 else {
            return false
        }
        close(descriptor)
        return true
    }
}
#endif
