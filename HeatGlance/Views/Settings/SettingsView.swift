import SwiftUI

import HeatGlanceCore

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("General", systemImage: "gear") }
            ThresholdsSettingsView()
                .tabItem { Label("Thresholds", systemImage: "slider.horizontal.3") }
            ProtectionSettingsView()
                .tabItem { Label("Protection", systemImage: "shield") }
            IgnoredItemsView()
                .tabItem { Label("Ignored", systemImage: "bell.slash") }
        }
        .frame(width: 520, height: 420)
    }
}
