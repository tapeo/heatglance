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

    var onChange: (() -> Void)?

    init() {
        settings = Self.read(AppSettings.self, key: "heatglance.appSettings") ?? .defaults
        protection = Self.read(ProtectionSettings.self, key: "heatglance.protection") ?? .defaults
        presence = Self.read(PresenceSettings.self, key: "heatglance.presence") ?? .defaults
        launchAtLogin = UserDefaults.standard.bool(forKey: "heatglance.launchAtLogin")
        sampleFast = UserDefaults.standard.bool(forKey: "heatglance.sampleFast")
        weeklySummaryEnabled = UserDefaults.standard.bool(forKey: "heatglance.weeklySummary")
        largeFileThresholdGB = UserDefaults.standard.double(forKey: "heatglance.largeFileGB")
        if largeFileThresholdGB == 0 {
            largeFileThresholdGB = 1
        }
        excludedFolders = UserDefaults.standard.stringArray(forKey: "heatglance.excludedFolders") ?? []
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
