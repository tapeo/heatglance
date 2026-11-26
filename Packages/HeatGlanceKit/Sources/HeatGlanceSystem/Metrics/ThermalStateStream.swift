import Foundation

#if canImport(Darwin)
import Darwin

public enum ThermalStateStream {
    public static func make() -> AsyncStream<ThermalLevel> {
        AsyncStream { continuation in
            _ = ProcessInfo.processInfo.thermalState
            let observer = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                continuation.yield(ThermalReader.currentLevel())
            }
            continuation.yield(ThermalReader.currentLevel())
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
#endif
