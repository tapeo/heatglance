import Foundation

import HeatGlanceCore

#if canImport(AppKit) && canImport(Darwin)
import AppKit
import CoreMediaIO
import CoreAudio
import IOKit
import Darwin

public actor PresenceMonitor {
    private let policy = PresencePolicy()
    private var screenIsLocked = false
    private var screensAreAsleep = false
    private var sessionIsActive = true
    private var screenSaverIsRunning = false
    private var observers: [NSObjectProtocol] = []
    private var distributedObservers: [NSObjectProtocol] = []

    public init() {}

    public func start() -> AsyncStream<PresenceSignals> {
        AsyncStream { continuation in
            self.installObservers()
            let task = Task {
                while !Task.isCancelled {
                    continuation.yield(self.currentSignals())
                    try? await Task.sleep(for: .seconds(5))
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func currentSignals() -> PresenceSignals {
        PresenceSignals(
            screenIsLocked: screenIsLocked,
            screensAreAsleep: screensAreAsleep,
            sessionIsActive: sessionIsActive,
            screenSaverIsRunning: screenSaverIsRunning,
            idleSeconds: IdleTimeReader.idleSeconds(),
            displaySleepPrevented: SleepAssertionsReader.isDisplaySleepPrevented(),
            microphoneInUse: CaptureDeviceObserver.microphoneInUse(),
            cameraInUse: CaptureDeviceObserver.cameraInUse()
        )
    }

    public func presence(settings: PresenceSettings) -> Presence {
        policy.evaluate(currentSignals(), settings: settings)
    }

    private func installObservers() {
        guard observers.isEmpty && distributedObservers.isEmpty else {
            return
        }
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setScreensAsleep(true) }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setScreensAsleep(false) }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setSessionActive(false) }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setSessionActive(true) }
        })

        let center = DistributedNotificationCenter.default()
        distributedObservers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setLocked(true) }
        })
        distributedObservers.append(center.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setLocked(false) }
        })
        distributedObservers.append(center.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstart"), object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setScreenSaver(true) }
        })
        distributedObservers.append(center.addObserver(forName: NSNotification.Name("com.apple.screensaver.didstop"), object: nil, queue: .main) { [weak self] _ in
            Task { await self?.setScreenSaver(false) }
        })

        screenIsLocked = SessionState.isScreenLocked()
    }

    private func setLocked(_ value: Bool) {
        screenIsLocked = value
    }

    private func setScreensAsleep(_ value: Bool) {
        screensAreAsleep = value
    }

    private func setSessionActive(_ value: Bool) {
        sessionIsActive = value
    }

    private func setScreenSaver(_ value: Bool) {
        screenSaverIsRunning = value
    }
}

public enum SessionState {
    public static func isScreenLocked() -> Bool {
        guard let dictionary = CGSessionCopyCurrentDictionary() as? [String: Any] else {
            return false
        }
        return (dictionary["CGSSessionScreenIsLocked"] as? Bool) ?? false
    }
}

public enum IdleTimeReader {
    public static func idleSeconds() -> Double {
        let anyInput = CGEventType(rawValue: UInt32.max)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

public enum CaptureDeviceObserver {
    public static func microphoneInUse() -> Bool {
        guard let device = inputDevice() else {
            return false
        }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        let result = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running)
        return result == noErr && running != 0
    }

    public static func cameraInUse() -> Bool {
        var device = CMIOObjectID(0)
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDefaultInputDevice),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var size = UInt32(MemoryLayout<CMIOObjectID>.size)
        let result = CMIOObjectGetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<CMIOObjectID>.size),
            &size,
            &device
        )
        guard result == noErr, device != 0 else {
            return false
        }
        var runningAddress = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var running: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        let runningResult = CMIOObjectGetPropertyData(
            device,
            &runningAddress,
            0,
            nil,
            UInt32(MemoryLayout<UInt32>.size),
            &runningSize,
            &running
        )
        return runningResult == noErr && running != 0
    }

    private static func inputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let result = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            &device
        )
        guard result == noErr, device != 0 else {
            return nil
        }
        return device
    }
}

public enum DisplaySleeper {
    public static func sleepDisplay() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["displaysleepnow"]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                return true
            }
        } catch {
        }
        return ioKitSleep()
    }

    private static func ioKitSleep() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IODisplayWrangler"))
        guard service != 0 else {
            return false
        }
        defer { IOObjectRelease(service) }
        let value = kCFBooleanTrue
        let result = IORegistryEntrySetCFProperty(service, "IORequestIdle" as CFString, value)
        return result == kIOReturnSuccess
    }
}
#endif
