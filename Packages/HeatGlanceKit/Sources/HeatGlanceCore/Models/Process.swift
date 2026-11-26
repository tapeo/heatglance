import Foundation

public struct ProcessIdentity: Hashable, Sendable, Codable {
    public let pid: Int32
    public let startTime: Date

    public init(pid: Int32, startTime: Date) {
        self.pid = pid
        self.startTime = startTime
    }
}

public struct ProcessSnapshot: Sendable, Identifiable {
    public let identity: ProcessIdentity
    public let parentPID: Int32
    public let userID: UInt32
    public let name: String
    public let executablePath: String?
    public let cpuPercent: Double
    public let footprintBytes: UInt64
    public let bytesWritten: UInt64
    public let startedAt: Date

    public var id: ProcessIdentity {
        identity
    }

    public init(
        identity: ProcessIdentity,
        parentPID: Int32,
        userID: UInt32,
        name: String,
        executablePath: String?,
        cpuPercent: Double,
        footprintBytes: UInt64,
        bytesWritten: UInt64
    ) {
        self.identity = identity
        self.parentPID = parentPID
        self.userID = userID
        self.name = name
        self.executablePath = executablePath
        self.cpuPercent = cpuPercent
        self.footprintBytes = footprintBytes
        self.bytesWritten = bytesWritten
        self.startedAt = identity.startTime
    }
}

public struct ProcessGroup: Sendable, Identifiable, Hashable {
    public let id: String
    public let displayName: String
    public let bundleIdentifier: String?
    public let members: [ProcessSnapshot]

    public init(id: String, displayName: String, bundleIdentifier: String?, members: [ProcessSnapshot]) {
        self.id = id
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.members = members
    }

    public var cpuPercent: Double {
        members.reduce(0) { $0 + $1.cpuPercent }
    }

    public var footprintBytes: UInt64 {
        members.reduce(0) { $0 + $1.footprintBytes }
    }

    public var bytesWritten: UInt64 {
        members.reduce(0) { $0 + $1.bytesWritten }
    }

    public var isApplication: Bool {
        bundleIdentifier != nil
    }

    public var identities: [ProcessIdentity] {
        members.map(\.identity)
    }

    public static func == (lhs: ProcessGroup, rhs: ProcessGroup) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
