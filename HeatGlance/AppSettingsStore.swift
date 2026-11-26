import Foundation

import HeatGlanceCore
import HeatGlanceSystem

@MainActor
@Observable
final class AppSettingsStore {
    private let defaults = UserDefaults.standard

    var settings: AppSettings {
        didSet { persist() }
    }
    var protection: ProtectionSettings {
        didSet { persist() }
    }
    var presence: PresenceSettings {
        didSet { persist() }
    }
    var launchAtLogin: Bool {
        didSet { persist() }
    }
    var sampleFast: Bool {
        didSet { persist() }
    }
    var weeklySummaryEnabled: Bool {
        didSet { persist() }
    }
    var largeFileThresholdGB: Double {
        didSet { persist() }
    }
    var excludedFolders: [String] {
        didSet { persist() }
    }
    var didSetup: Bool {
        didSet { persist() }
    }

    var onChange: (() -> Void)?

    init() {
        let defaults = UserDefaults.standard
        let storedSettings = Self.read(AppSettings.self, key: "heatglance.appSettings") ?? .defaults
        let storedProtection = Self.read(ProtectionSettings.self, key: "heatglance.protection") ?? .defaults
        let storedPresence = Self.read(PresenceSettings.self, key: "heatglance.presence") ?? .defaults
        var threshold = defaults.double(forKey: "heatglance.largeFileGB")
        if threshold == 0 {
            threshold = 1
        }

        self.settings = storedSettings
        self.protection = storedProtection
        self.presence = storedPresence
        self.launchAtLogin = defaults.bool(forKey: "heatglance.launchAtLogin")
        self.sampleFast = defaults.bool(forKey: "heatglance.sampleFast")
        self.weeklySummaryEnabled = defaults.bool(forKey: "heatglance.weeklySummary")
        self.largeFileThresholdGB = threshold
        self.excludedFolders = defaults.stringArray(forKey: "heatglance.excludedFolders") ?? []
        self.didSetup = defaults.bool(forKey: "heatglance.didSetup")
    }

    private func persist() {
        Self.write(settings, key: "heatglance.appSettings")
        Self.write(protection, key: "heatglance.protection")
        Self.write(presence, key: "heatglance.presence")
        defaults.set(launchAtLogin, forKey: "heatglance.launchAtLogin")
        defaults.set(sampleFast, forKey: "heatglance.sampleFast")
        defaults.set(weeklySummaryEnabled, forKey: "heatglance.weeklySummary")
        defaults.set(largeFileThresholdGB, forKey: "heatglance.largeFileGB")
        defaults.set(excludedFolders, forKey: "heatglance.excludedFolders")
        defaults.set(didSetup, forKey: "heatglance.didSetup")
        onChange?()
    }

    private static func read<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func write<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else {
            return
        }
        UserDefaults.standard.set(data, forKey: key)
    }
}
