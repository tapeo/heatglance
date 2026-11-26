import Foundation

public enum AppBundlePath {
    public static func containing(executablePath: String) -> String? {
        guard let range = executablePath.range(of: ".app/") else {
            return nil
        }
        return String(executablePath[..<range.upperBound].dropLast())
    }

    public static func isRunning(executablePath: String?, runningBundlePaths: Set<String>) -> Bool {
        guard let executablePath, let bundlePath = containing(executablePath: executablePath) else {
            return false
        }
        return runningBundlePaths.contains(bundlePath)
    }
}
