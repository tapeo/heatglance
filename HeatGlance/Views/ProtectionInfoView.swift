import SwiftUI

import HeatGlanceCore

struct ProtectionInfoView: View {
    @Environment(AppSettingsStore.self) private var settings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("How thermal protection works")
                    .font(.title2.bold())
                Text(statusLine)
                    .foregroundStyle(.secondary)
                ForEach(ProtectionExplanation.sections(protection: settings.protection, presence: settings.presence)) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                        ForEach(section.paragraphs, id: \.self) { paragraph in
                            Text(paragraph)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 420, minHeight: 360)
    }

    private var statusLine: String {
        if settings.protection.isEnabled {
            return "Protection is on."
        }
        return "Protection is off. Turn it on from the menu or in Settings."
    }
}
