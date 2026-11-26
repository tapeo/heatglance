import Foundation

public struct CacheItem: Sendable, Identifiable, Hashable {
    public enum Method: Sendable, Hashable {
        case trash
        case command(executable: String, arguments: [String])
    }

    public let id: String
    public let title: String
    public let detail: String
    public let path: String?
    public let command: [String]?
    public let method: Method

    public init(id: String, title: String, detail: String, path: String?, command: [String]?, method: Method) {
        self.id = id
        self.title = title
        self.detail = detail
        self.path = path
        self.command = command
        self.method = method
    }
}

public struct CacheCatalog: Sendable {
    public init() {}

    public var items: [CacheItem] {
        [
            CacheItem(
                id: "derived_data",
                title: "Xcode DerivedData",
                detail: "Build products and indexes. Xcode rebuilds them when needed.",
                path: "~/Library/Developer/Xcode/DerivedData",
                command: nil,
                method: .trash
            ),
            CacheItem(
                id: "ios_device_support",
                title: "iOS DeviceSupport",
                detail: "Debug symbols for iOS versions you connected. Downloaded again when needed.",
                path: "~/Library/Developer/Xcode/iOS DeviceSupport",
                command: nil,
                method: .trash
            ),
            CacheItem(
                id: "simulators",
                title: "Unavailable simulators",
                detail: "Simulator runtimes no longer installed.",
                path: nil,
                command: ["xcrun", "simctl", "delete", "unavailable"],
                method: .command(executable: "xcrun", arguments: ["simctl", "delete", "unavailable"])
            ),
            CacheItem(
                id: "homebrew",
                title: "Homebrew downloads",
                detail: "Installer archives kept by Homebrew.",
                path: nil,
                command: ["brew", "cleanup", "--prune=all"],
                method: .command(executable: "brew", arguments: ["cleanup", "--prune=all"])
            ),
            CacheItem(
                id: "npm",
                title: "npm cache",
                detail: "Downloaded packages kept by npm.",
                path: nil,
                command: ["npm", "cache", "clean", "--force"],
                method: .command(executable: "npm", arguments: ["cache", "clean", "--force"])
            ),
            CacheItem(
                id: "pnpm",
                title: "pnpm store",
                detail: "Packages no longer referenced by any project.",
                path: nil,
                command: ["pnpm", "store", "prune"],
                method: .command(executable: "pnpm", arguments: ["store", "prune"])
            ),
            CacheItem(
                id: "docker",
                title: "Docker image cache",
                detail: "Images not used by any container. Docker has to be running.",
                path: nil,
                command: ["docker", "image", "prune"],
                method: .command(executable: "docker", arguments: ["image", "prune"])
            ),
        ]
    }

    public func item(id: String) -> CacheItem? {
        items.first { $0.id == id }
    }
}
