import Foundation

public struct ExcludedFolders: Sendable, Equatable {
    public let paths: [String]

    public init(rawPaths: [String], home: String) {
        var normalized: [String] = []
        for raw in rawPaths {
            guard let path = Self.normalize(raw, home: home), !normalized.contains(path) else {
                continue
            }
            normalized.append(path)
        }
        paths = normalized
    }

    public func contains(_ path: String) -> Bool {
        paths.contains { excluded in
            path == excluded || path.hasPrefix(excluded + "/")
        }
    }

    public func inside(_ root: String) -> [String] {
        paths.filter { $0.hasPrefix(root + "/") }
    }

    static func normalize(_ raw: String, home: String) -> String? {
        var path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if path == "~" {
            path = home
        } else if path.hasPrefix("~/") {
            path = home + String(path.dropFirst(1))
        }
        guard path.hasPrefix("/") else {
            return nil
        }
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        guard path != "/" else {
            return nil
        }
        return path
    }
}
