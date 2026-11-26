import AppKit
import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct SetupView: View {
    @Environment(Monitor.self) private var monitor
    @Environment(AppSettingsStore.self) private var settings
    @Environment(\.openWindow) private var openWindow
    @State private var requestedNotifications = false
    @State private var hasFullDiskAccess = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A few permissions")
                .font(.title2.bold())
            step(
                title: "Notifications",
                detail: "HeatGlance tells you when something needs attention. Nothing is sent anywhere.",
                button: "Allow",
                completed: requestedNotifications,
                buttonEnabled: !requestedNotifications
            ) {
                requestedNotifications = true
                Task {
                    await Notifier().requestAuthorization()
                }
            }
            step(
                title: "Full disk access (optional)",
                detail: "Without it HeatGlance never looks inside Desktop, Documents, Downloads, Movies, Pictures, Music or your Library caches, so macOS never asks about them. With it, HeatGlance also watches those folders for large files and growth.",
                button: "Open settings",
                completed: hasFullDiskAccess,
                buttonEnabled: !hasFullDiskAccess
            ) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                    NSWorkspace.shared.open(url)
                }
            }
            step(
                title: "Thermal protection",
                detail: "Pauses apps that heat the Mac, only while you are away. On by default.",
                button: protectionButtonTitle,
                completed: settings.protection.isEnabled,
                buttonEnabled: true
            ) {
                monitor.toggleProtection()
            }
            Button("How thermal protection works") {
                openWindow(id: "protection-info")
            }
            .buttonStyle(.link)
            .controlSize(.small)
            .padding(.leading, 28)
            Spacer()
            HStack {
                Text("Every step can be skipped.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    settings.didSetup = true
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 360)
        .onAppear {
            hasFullDiskAccess = FullDiskAccess.isGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasFullDiskAccess = FullDiskAccess.isGranted()
        }
    }

    private var protectionButtonTitle: String {
        if settings.protection.isEnabled {
            return "Turn off"
        }
        return "Turn on"
    }

    private func step(
        title: String,
        detail: String,
        button: String,
        completed: Bool,
        buttonEnabled: Bool,
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
                .disabled(!buttonEnabled)
                .controlSize(.small)
        }
    }
}
