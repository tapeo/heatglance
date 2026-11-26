import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct ProtectionSettingsView: View {
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Thermal protection") {
                Toggle("Pause apps that heat the Mac while I am away", isOn: $settings.protection.isEnabled)
                Picker("Trigger at", selection: $settings.protection.triggerLevel) {
                    Text("Serious").tag(ThermalLevel.serious)
                    Text("Critical").tag(ThermalLevel.critical)
                }
                Text("Heat must last for \(Int(settings.protection.sustainSeconds)) seconds before HeatGlance acts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: $settings.protection.sustainSeconds,
                    in: 15...300,
                    step: 5
                ) {
                    Text("Sustain")
                }
            }
            Section("Presence") {
                Text("Idle before away: \(Int(settings.presence.idleThresholdSeconds / 60)) minutes")
                    .font(.caption)
                Slider(value: $settings.presence.idleThresholdSeconds, in: 60...1800, step: 60) {
                    Text("Idle")
                }
                Toggle("Video or presentation keeps me present", isOn: $settings.presence.useDisplaySleepAssertion)
                Toggle("Microphone keeps me present", isOn: $settings.presence.useMicrophone)
                Toggle("Camera keeps me present", isOn: $settings.presence.useCamera)
            }
            Section("Never pause") {
                Text("Add bundle identifiers, one per line. Apps listed here are never paused by the protection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: Binding(
                    get: { settings.protection.neverPause.joined(separator: "\n") },
                    set: { settings.protection.neverPause = $0.split(separator: "\n").map(String.init) }
                ))
                .frame(height: 70)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
