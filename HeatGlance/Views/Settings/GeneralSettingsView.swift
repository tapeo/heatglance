import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct GeneralSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings
    @Environment(Monitor.self) private var monitor

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Startup") {
                Toggle("Launch HeatGlance at login", isOn: $settings.launchAtLogin)
            }
            Section("Frequent updates") {
                Toggle("Sample every 2 seconds (uses more power)", isOn: $settings.sampleFast)
                Text("When off, HeatGlance samples every 5 seconds on power and every 10 seconds on battery.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Files") {
                HStack {
                    Text("Notify for files larger than")
                    TextField("GB", value: $settings.largeFileThresholdGB, format: .number)
                        .frame(width: 60)
                    Text("GB")
                }
            }
            Section("Summary") {
                Toggle("Weekly summary notification", isOn: $settings.weeklySummaryEnabled)
            }
            #if DEBUG
            Section("Debug") {
                Picker("Simulation", selection: Binding(
                    get: { monitor.thermalOverride },
                    set: { monitor.setThermalOverride($0) }
                )) {
                    Text("Off").tag(ThermalLevel?.none)
                    Text("Nominal").tag(ThermalLevel?.some(.nominal))
                    Text("Serious").tag(ThermalLevel?.some(.serious))
                    Text("Critical").tag(ThermalLevel?.some(.critical))
                }
            }
            #endif
        }
        .formStyle(.grouped)
        .padding()
    }
}
