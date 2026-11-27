import AppKit
import Foundation
import UniformTypeIdentifiers

import HeatGlanceCore

@MainActor
enum HistoryExporter {
    static func copyEvents(_ events: [HistoryEvent]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(HistoryExport.eventsText(events), forType: .string)
    }

    static func saveEvents(_ events: [HistoryEvent]) {
        save(text: HistoryExport.eventsCSV(events), name: "heatglance-events")
    }

    static func saveMinutes(_ points: [HistoryPoint]) {
        save(text: HistoryExport.pointsCSV(points), name: "heatglance-minutes")
    }

    private static func save(text: String, name: String) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "\(name)-\(formatter.string(from: Date())).csv"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else {
            return
        }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
