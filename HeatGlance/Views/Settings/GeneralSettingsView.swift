import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct GeneralSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Startup") {
                Toggle("Launch HeatGlance at login", isOn: $settings.launchAtLogin)
            }
            Section("Frequent updates") {
                Toggle("Sample every 2 seconds (uses more power)", isOn: $settings.sampleFast)
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
        }
        .formStyle(.grouped)
        .padding()
    }
}
