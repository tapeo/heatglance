import Foundation

public enum CacheSizeSource: Sendable, Hashable {
    case folder(path: String)
    case unavailableSimulators
    case homebrewCache
    case npmCache
    case pnpmStore
    case dockerImages

    public var isUpperBound: Bool {
        switch self {
        case .pnpmStore, .dockerImages:
            return true
        case .folder, .unavailableSimulators, .homebrewCache, .npmCache:
            return false
        }
    }
}

public struct CacheItem: Sendable, Identifiable, Hashable {
    public enum Method: Sendable, Hashable {
        case trash
        case command(executable: String, arguments: [String])
    }

    public let id: String
    public let title: String
    public let detail: String
    public let path: String?
    public let size: CacheSizeSource
    public let method: Method

    public init(id: String, title: String, detail: String, path: String?, size: CacheSizeSource, method: Method) {
        self.id = id
        self.title = title
        self.detail = detail
        self.path = path
        self.size = size
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
                size: .folder(path: "~/Library/Developer/Xcode/DerivedData"),
                method: .trash
            ),
            CacheItem(
                id: "ios_device_support",
                title: "iOS DeviceSupport",
                detail: "Debug symbols for iOS versions you connected. Downloaded again when needed.",
                path: "~/Library/Developer/Xcode/iOS DeviceSupport",
                size: .folder(path: "~/Library/Developer/Xcode/iOS DeviceSupport"),
                method: .trash
            ),
            CacheItem(
                id: "simulators",
                title: "Unavailable simulators",
                detail: "Simulator devices whose runtime is no longer installed.",
                path: nil,
                size: .unavailableSimulators,
                method: .command(executable: "xcrun", arguments: ["simctl", "delete", "unavailable"])
            ),
            CacheItem(
                id: "homebrew",
                title: "Homebrew downloads",
                detail: "Installer archives kept by Homebrew.",
                path: nil,
                size: .homebrewCache,
                method: .command(executable: "brew", arguments: ["cleanup", "--prune=all"])
            ),
            CacheItem(
                id: "npm",
                title: "npm cache",
                detail: "Downloaded packages kept by npm.",
                path: nil,
                size: .npmCache,
                method: .command(executable: "npm", arguments: ["cache", "clean", "--force"])
            ),
            CacheItem(
                id: "pnpm",
                title: "pnpm store",
                detail: "Packages no longer referenced by any project. The size counts the whole store, so cleaning frees less.",
                path: nil,
                size: .pnpmStore,
                method: .command(executable: "pnpm", arguments: ["store", "prune"])
            ),
            CacheItem(
                id: "docker",
                title: "Docker image cache",
                detail: "Untagged images left behind by rebuilds. The size counts every unused image, so cleaning can free less. Docker has to be running.",
                path: nil,
                size: .dockerImages,
                method: .command(executable: "docker", arguments: ["image", "prune", "-f"])
            ),
        ]
    }

    public func item(id: String) -> CacheItem? {
        items.first { $0.id == id }
    }
}
