import AppKit
import SwiftUI

struct MenuFooterView: View {
    @Environment(Monitor.self) private var monitor

    let showWindow: (String) -> Void
    let showSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !monitor.settings.didSetup {
                HStack {
                    Text("Setup isn't finished")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Finish setup") {
                        monitor.settings.didSetup = true
                        showWindow("setup")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            HStack(spacing: 4) {
                Button {
                    monitor.sleepDisplay()
                } label: {
                    Label("Sleep display", systemImage: "moon.zzz")
                }
                .controlSize(.small)
                Spacer()
                iconButton("Cleanup", systemImage: "internaldrive") {
                    showWindow("cleanup")
                }
                iconButton("History", systemImage: "clock.arrow.circlepath") {
                    showWindow("history")
                }
                iconButton("Settings", systemImage: "gearshape") {
                    showSettings()
                }
                iconButton("Quit HeatGlance", systemImage: "power") {
                    NSApplication.shared.terminate(nil)
                }
                .padding(.leading, 6)
            }
        }
    }

    private func iconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .help(title)
    }
}
