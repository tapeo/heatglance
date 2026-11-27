import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("History store")
struct HistoryStoreTests {
    let start = Fixtures.baseDate

    @Test("Recording keeps temperature, away and paused apps")
    func recordContext() throws {
        var store = HistoryStore()
        store.record(Fixtures.sample(date: start, temperature: 80), isAway: true, pausedApps: 2)
        #expect(store.points.count == 1)
        let point = try #require(store.points.first)
        #expect(point.temperatureCelsius == 80)
        #expect(point.isAway == true)
        #expect(point.pausedApps == 2)
    }

    @Test("A history file from the previous version still loads")
    func compatibility() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heatglance-history-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent("history.json")
        let json = """
        {
          "points": [
            {
              "minute": "2023-11-14T22:13:00Z",
              "thermal": 2,
              "memoryPressure": 1,
              "systemCPUPercent": 42.5,
              "swapUsedBytes": 0,
              "diskAvailableBytes": 500000000000,
              "worstGroupCPU": 182
            }
          ]
        }
        """
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)

        let loaded = try JSONFileStore.load(HistoryStore.self, from: url)
        let point = try #require(loaded?.points.first)
        #expect(loaded?.points.count == 1)
        #expect(point.systemCPUPercent == 42.5)
        #expect(point.temperatureCelsius == nil)
        #expect(point.isAway == nil)
        #expect(point.pausedApps == nil)
    }

    @Test("Points older than seven days are dropped")
    func retention() {
        var store = HistoryStore()
        store.record(Fixtures.sample(date: start.addingTimeInterval(-8 * 86_400)))
        store.record(Fixtures.sample(date: start.addingTimeInterval(-6 * 86_400)))
        store.record(Fixtures.sample(date: start))

        #expect(store.points.count == 2)
        let kept = HistoryPoint.minute(of: start.addingTimeInterval(-6 * 86_400))
        #expect(store.points.contains { $0.minute == kept })
    }
}
