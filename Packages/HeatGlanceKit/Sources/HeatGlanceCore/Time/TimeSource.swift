import Foundation

public protocol TimeSource: Sendable {
    func now() -> Date
    func sleep(for duration: Duration) async throws
}

public struct SystemTimeSource: TimeSource {
    public init() {}

    public func now() -> Date {
        Date()
    }

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

public final class ManualTimeSource: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private var pending: [(deadline: Date, continuation: CheckedContinuation<Void, Error>)] = []
    private var isCancelled = false

    public init(start: Date = Date(timeIntervalSince1970: 1_000_000)) {
        self.current = start
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    public func sleep(for duration: Duration) async throws {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        let deadline = now().addingTimeInterval(seconds)
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            lock.lock()
            defer { lock.unlock() }
            if isCancelled {
                continuation.resume(throwing: CancellationError())
                return
            }
            pending.append((deadline, continuation))
        }
    }

    public func advance(by duration: Duration) {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        advance(bySeconds: seconds)
    }

    public func advance(bySeconds seconds: Double) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        let ready = pending.filter { $0.deadline <= current }
        pending.removeAll { $0.deadline <= current }
        lock.unlock()
        for entry in ready {
            entry.continuation.resume()
        }
    }

    public func set(now date: Date) {
        lock.lock()
        current = date
        let ready = pending.filter { $0.deadline <= current }
        pending.removeAll { $0.deadline <= current }
        lock.unlock()
        for entry in ready {
            entry.continuation.resume()
        }
    }

    public func cancelAll() {
        lock.lock()
        isCancelled = true
        let ready = pending
        pending.removeAll()
        lock.unlock()
        for entry in ready {
            entry.continuation.resume(throwing: CancellationError())
        }
    }
}

public final class AcceleratedTimeSource: TimeSource, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date
    private let multiplier: Double

    public init(start: Date = Date(), multiplier: Double) {
        self.current = start
        self.multiplier = multiplier
    }

    public func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    public func sleep(for duration: Duration) async throws {
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        let real = seconds / multiplier
        try await Task.sleep(nanoseconds: UInt64(max(real, 0) * 1_000_000_000))
        advanceSynchronously(bySeconds: seconds)
    }

    private nonisolated func advanceSynchronously(bySeconds seconds: Double) {
        lock.lock()
        current = current.addingTimeInterval(seconds)
        lock.unlock()
    }
}
