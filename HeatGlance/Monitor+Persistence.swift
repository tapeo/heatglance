import Foundation

import HeatGlanceCore

extension Monitor {
    func loadIgnoreList() {
        if let stored = try? JSONFileStore.load(IgnoreList.self, from: SupportDirectory.url(file: "ignored.json")) {
            ignoreList = stored
        }
    }

    func persistIgnoreList() {
        try? JSONFileStore.save(ignoreList, to: SupportDirectory.url(file: "ignored.json"))
    }

    func loadHistory() {
        if let stored = try? JSONFileStore.load(HistoryStore.self, from: SupportDirectory.url(file: "history.json")) {
            history = stored
        }
        if let stored = try? JSONFileStore.load(TrendsEngine.self, from: SupportDirectory.url(file: "trends.json")) {
            trends = stored
        }
        loadEvents()
    }

    func saveHistory() {
        try? JSONFileStore.save(history, to: SupportDirectory.url(file: "history.json"))
    }

    func saveTrends() {
        try? JSONFileStore.save(trends, to: SupportDirectory.url(file: "trends.json"))
    }

    func loadEvents() {
        if let stored = try? JSONFileStore.load(HistoryEventLog.self, from: SupportDirectory.url(file: "events.json")) {
            eventLog = stored
        }
    }

    func saveEvents() {
        try? JSONFileStore.save(eventLog, to: SupportDirectory.url(file: "events.json"))
    }
}
