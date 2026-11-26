import Foundation

public struct PresenceSignals: Sendable, Equatable {
    public let screenIsLocked: Bool
    public let screensAreAsleep: Bool
    public let sessionIsActive: Bool
    public let screenSaverIsRunning: Bool
    public let idleSeconds: Double
    public let displaySleepPrevented: Bool
    public let microphoneInUse: Bool
    public let cameraInUse: Bool

    public init(
        screenIsLocked: Bool = false,
        screensAreAsleep: Bool = false,
        sessionIsActive: Bool = true,
        screenSaverIsRunning: Bool = false,
        idleSeconds: Double = 0,
        displaySleepPrevented: Bool = false,
        microphoneInUse: Bool = false,
        cameraInUse: Bool = false
    ) {
        self.screenIsLocked = screenIsLocked
        self.screensAreAsleep = screensAreAsleep
        self.sessionIsActive = sessionIsActive
        self.screenSaverIsRunning = screenSaverIsRunning
        self.idleSeconds = idleSeconds
        self.displaySleepPrevented = displaySleepPrevented
        self.microphoneInUse = microphoneInUse
        self.cameraInUse = cameraInUse
    }

    public var hasPassiveSignal: Bool {
        displaySleepPrevented || microphoneInUse || cameraInUse
    }
}

public struct PresenceSettings: Sendable, Codable, Equatable {
    public var idleThresholdSeconds: Double
    public var passiveCapSeconds: Double
    public var useDisplaySleepAssertion: Bool
    public var useMicrophone: Bool
    public var useCamera: Bool

    public init(
        idleThresholdSeconds: Double = 300,
        passiveCapSeconds: Double = 3600,
        useDisplaySleepAssertion: Bool = true,
        useMicrophone: Bool = true,
        useCamera: Bool = true
    ) {
        self.idleThresholdSeconds = idleThresholdSeconds
        self.passiveCapSeconds = passiveCapSeconds
        self.useDisplaySleepAssertion = useDisplaySleepAssertion
        self.useMicrophone = useMicrophone
        self.useCamera = useCamera
    }

    public static let defaults = PresenceSettings()
}

public enum Presence: Sendable, Equatable {
    case present
    case passive
    case absent

    public var isAway: Bool {
        self == .absent
    }
}

public struct PresencePolicy {
    public init() {}

    public func evaluate(_ signals: PresenceSignals, settings: PresenceSettings) -> Presence {
        if signals.screenIsLocked || signals.screensAreAsleep || !signals.sessionIsActive || signals.screenSaverIsRunning {
            return .absent
        }
        if signals.idleSeconds < settings.idleThresholdSeconds {
            return .present
        }
        if hasEnabledPassiveSignal(signals, settings: settings) && signals.idleSeconds < settings.passiveCapSeconds {
            return .passive
        }
        return .absent
    }

    private func hasEnabledPassiveSignal(_ signals: PresenceSignals, settings: PresenceSettings) -> Bool {
        let assertion = settings.useDisplaySleepAssertion && signals.displaySleepPrevented
        let microphone = settings.useMicrophone && signals.microphoneInUse
        let camera = settings.useCamera && signals.cameraInUse
        return assertion || microphone || camera
    }
}
