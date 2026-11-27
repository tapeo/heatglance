import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

@main
struct HeatGlanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let monitor = Monitor.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environment(monitor)
                .environment(monitor.settings)
        } label: {
            Label("HeatGlance", systemImage: symbol)
        }
        .menuBarExtraStyle(.window)

        Window("Cleanup", id: "cleanup") {
            CleanupView()
                .environment(monitor)
                .environment(monitor.settings)
        }
        .defaultSize(width: 620, height: 480)

        Window("History", id: "history") {
            HistoryView()
                .environment(monitor)
                .environment(monitor.settings)
        }
        .defaultSize(width: 760, height: 680)

        Window("Setup", id: "setup") {
            SetupView()
                .environment(monitor)
                .environment(monitor.settings)
        }
        .defaultSize(width: 520, height: 420)

        Window("Thermal protection", id: "protection-info") {
            ProtectionInfoView()
                .environment(monitor)
                .environment(monitor.settings)
        }
        .defaultSize(width: 480, height: 560)

        Settings {
            SettingsView()
                .environment(monitor)
                .environment(monitor.settings)
        }
    }

    private var symbol: String {
        switch monitor.overall {
        case .normal:
            return "thermometer.low"
        case .elevated:
            return "thermometer.medium"
        case .critical:
            return "thermometer.high"
        }
    }
}
