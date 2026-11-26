import Foundation

public struct KnownItem: Codable, Sendable, Identifiable, Hashable {
    public struct Match: Codable, Sendable, Hashable {
        public let processNames: [String]?
        public let bundleIdentifiers: [String]?
        public let pathPrefixes: [String]?

        public init(processNames: [String]? = nil, bundleIdentifiers: [String]? = nil, pathPrefixes: [String]? = nil) {
            self.processNames = processNames
            self.bundleIdentifiers = bundleIdentifiers
            self.pathPrefixes = pathPrefixes
        }
    }

    public let id: String
    public let match: Match
    public let title: String
    public let explanation: String
    public let typicalBehavior: String
    public let suggestedAction: String
    public let safeToStop: Bool

    public init(
        id: String,
        match: Match,
        title: String,
        explanation: String,
        typicalBehavior: String,
        suggestedAction: String,
        safeToStop: Bool
    ) {
        self.id = id
        self.match = match
        self.title = title
        self.explanation = explanation
        self.typicalBehavior = typicalBehavior
        self.suggestedAction = suggestedAction
        self.safeToStop = safeToStop
    }
}

public final class KnowledgeBase: @unchecked Sendable {
    public static let shared = KnowledgeBase()

    public let items: [KnownItem]

    public init(items: [KnownItem]? = nil) {
        if let items {
            self.items = items
            return
        }
        self.items = Self.loadBundled()
    }

    public func match(groupID: String, processName: String? = nil, executablePath: String? = nil) -> KnownItem? {
        items.first { item in
            if let bundleIdentifiers = item.match.bundleIdentifiers, bundleIdentifiers.contains(groupID) {
                return true
            }
            if let names = item.match.processNames, let processName, names.contains(processName) {
                return true
            }
            if let names = item.match.processNames, names.contains(groupID) {
                return true
            }
            if let prefixes = item.match.pathPrefixes, let executablePath {
                return prefixes.contains { executablePath.hasPrefix($0) }
            }
            return false
        }
    }

    public func match(path: String) -> KnownItem? {
        items.first { item in
            guard let prefixes = item.match.pathPrefixes else {
                return false
            }
            return prefixes.contains { path.hasPrefix($0) }
        }
    }

    private static func loadBundled() -> [KnownItem] {
        guard let url = Bundle.module.url(forResource: "known_items", withExtension: "json"),
              let data = try? Data(contentsOf: url)
        else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return (try? decoder.decode([KnownItem].self, from: data)) ?? []
    }
}
