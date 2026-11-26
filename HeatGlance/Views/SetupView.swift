import AppKit
import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct SetupView: View {
    @Environment(AppSettingsStore.self) private var settings
    @State private var requestedNotifications = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A few permissions")
                .font(.title2.bold())
            step(
                title: "Notifications",
                detail: "HeatGlance tells you when something needs attention. Nothing is sent anywhere.",
                button: "Allow",
                completed: requestedNotifications
            ) {
                requestedNotifications = true
                Task {
                    await Notifier().requestAuthorization()
                }
            }
            step(
                title: "Full disk access (optional)",
                detail: "Without it HeatGlance skips Desktop, Documents, Downloads and Mail when measuring folders.",
                button: "Open settings",
                completed: false
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            step(
                title: "Thermal protection",
                detail: "Pauses apps that heat the Mac, only while you are away. Off until you turn it on.",
                button: settings.protection.isEnabled ? "On" : "Turn on",
                completed: settings.protection.isEnabled
            ) {
                settings.protection.isEnabled = true
            }
            Spacer()
            Text("Every step can be skipped.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
    }

    private func step(
        title: String,
        detail: String,
        button: String,
        completed: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(completed ? .green : .secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button(button, action: action)
                .disabled(completed)
                .controlSize(.small)
        }
    }
}
