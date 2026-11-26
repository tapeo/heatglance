import Foundation

import HeatGlanceCore

#if canImport(Darwin)
public enum ThermalStateStream {
    public static func make() -> AsyncStream<ThermalLevel> {
        AsyncStream { continuation in
            _ = ProcessInfo.processInfo.thermalState
            let box = ObserverBox()
            let observer = NotificationCenter.default.addObserver(
                forName: ProcessInfo.thermalStateDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                continuation.yield(ThermalReader.currentLevel())
            }
            box.token = observer
            continuation.yield(ThermalReader.currentLevel())
            continuation.onTermination = { _ in
                box.cancel()
            }
        }
    }
}

final class ObserverBox: @unchecked Sendable {
    var token: NSObjectProtocol?

    func cancel() {
        guard let token else {
            return
        }
        NotificationCenter.default.removeObserver(token)
        self.token = nil
    }
}
#endif
