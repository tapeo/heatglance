import SwiftUI

import HeatGlanceCore

struct ThresholdsSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Thermal") {
                slider("Sustain before alert", value: $settings.settings.thermalSustainSeconds, range: 15...300, unit: "s")
            }
            Section("CPU") {
                slider("System CPU", value: $settings.settings.systemCPUThreshold, range: 50...100, unit: "%")
                slider("Process CPU", value: $settings.settings.processCPUThreshold, range: 50...400, unit: "%")
            }
            Section("Memory") {
                slider("Swap over physical memory", value: $settings.settings.swapRatioThreshold, range: 0.05...0.9, unit: "%", multiplier: 100)
            }
            Section("Disk") {
                slider("Free space in GB", value: $settings.settings.diskFreeGBThreshold, range: 5...100, unit: "GB")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func slider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        unit: String,
        multiplier: Double = 1
    ) -> some View {
        HStack {
            Text(title)
            Slider(value: value, in: range)
            Text(String(format: "%.0f %@", value.wrappedValue * multiplier, unit))
                .font(.caption.monospacedDigit())
                .frame(width: 64, alignment: .trailing)
        }
    }
}
