import Foundation

#if canImport(AppKit) && canImport(Darwin)
import AppKit
import Darwin

public enum ProcessActionResult: Sendable, Equatable {
    case done
    case identityChanged
    case notPermitted
    case failed(Int32)
}

public enum ProtectedProcesses {
    public static let names: Set<String> = [
        "WindowServer",
        "loginwindow",
        "Dock",
        "SystemUIServer",
        "ControlCenter",
        "launchd",
        "kernel_task",
        "coreaudiod",
        "Finder",
        "loginwindow",
    ]

    public static func isProtected(name: String, userID: UInt32, currentUserID: UInt32 = getuid()) -> Bool {
        if names.contains(name) {
            return true
        }
        if userID != currentUserID {
            return true
        }
        return false
    }
}

public enum ProcessActions {
    public static func suspend(_ identity: ProcessIdentity) -> ProcessActionResult {
        signal(identity, SIGSTOP)
    }

    public static func resume(_ identity: ProcessIdentity) -> ProcessActionResult {
        signal(identity, SIGCONT)
    }

    public static func quit(_ identity: ProcessIdentity) -> ProcessActionResult {
        guard ProcessIdentityVerifier.isAlive(identity) else {
            return .identityChanged
        }
        if let app = NSRunningApplication(processIdentifier: identity.pid) {
            if app.terminate() {
                return .done
            }
            return .failed(0)
        }
        return signal(identity, SIGTERM)
    }

    public static func forceQuit(_ identity: ProcessIdentity) -> ProcessActionResult {
        guard ProcessIdentityVerifier.isAlive(identity) else {
            return .identityChanged
        }
        if let app = NSRunningApplication(processIdentifier: identity.pid) {
            if app.forceTerminate() {
                return .done
            }
            return .failed(0)
        }
        return signal(identity, SIGKILL)
    }

    private static func signal(_ identity: ProcessIdentity, _ number: Int32) -> ProcessActionResult {
        guard ProcessIdentityVerifier.isAlive(identity) else {
            return .identityChanged
        }
        let result = kill(identity.pid, number)
        guard result == 0 else {
            let code = errno
            if code == EPERM {
                return .notPermitted
            }
            return .failed(code)
        }
        return .done
    }
}

public struct SuspendedProcessEntry: Sendable, Codable {
    public let identity: ProcessIdentity
    public let origin: Origin
    public let reason: String
    public let suspendedAt: Date

    public enum Origin: String, Sendable, Codable {
        case manual
        case protection
    }

    public init(identity: ProcessIdentity, origin: Origin, reason: String, suspendedAt: Date) {
        self.identity = identity
        self.origin = origin
        self.reason = reason
        self.suspendedAt = suspendedAt
    }
}

public actor SuspendedProcessRegistry {
    private var entries: [ProcessIdentity: SuspendedProcessEntry] = [:]
    private let url: URL
    private let defaultsKey: String

    public init(url: URL? = nil) {
        self.url = url ?? SupportDirectory.url(file: "suspended.json")
        self.defaultsKey = "heatglance.suspended"
        load()
    }

    public func record(_ entry: SuspendedProcessEntry) {
        entries[entry.identity] = entry
        persist()
    }

    public func remove(_ identity: ProcessIdentity) {
        entries.removeValue(forKey: identity)
        persist()
    }

    public func all() -> [SuspendedProcessEntry] {
        Array(entries.values)
    }

    public func identities(for origin: SuspendedProcessEntry.Origin?) -> [ProcessIdentity] {
        entries.values.filter { entry in
            guard let origin else {
                return true
            }
            return entry.origin == origin
        }.map(\.identity)
    }

    public func recoverAll(
        resume: @Sendable (ProcessIdentity) -> ProcessActionResult = { ProcessActions.resume($0) }
    ) -> [ProcessIdentity] {
        var recovered: [ProcessIdentity] = []
        for (identity, _) in entries {
            guard ProcessIdentityVerifier.isAlive(identity) else {
                continue
            }
            if resume(identity) == .done {
                recovered.append(identity)
            }
        }
        entries.removeAll()
        persist()
        return recovered
    }

    public func resumeAll(
        origin: SuspendedProcessEntry.Origin?,
        resume: @Sendable (ProcessIdentity) -> ProcessActionResult = { ProcessActions.resume($0) }
    ) {
        let targets = identities(for: origin)
        for identity in targets {
            _ = resume(identity)
            entries.removeValue(forKey: identity)
        }
        persist()
    }

    private func load() {
        guard let stored = try? JSONFileStore.load([SuspendedProcessEntry].self, from: url) else {
            return
        }
        entries = Dictionary(uniqueKeysWithValues: stored.map { ($0.identity, $0) })
    }

    private func persist() {
        try? JSONFileStore.save(Array(entries.values), to: url)
    }
}
#endif
