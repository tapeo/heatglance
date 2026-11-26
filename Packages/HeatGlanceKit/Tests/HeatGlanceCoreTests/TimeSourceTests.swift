import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("Time source")
struct TimeSourceTests {
    @Test("A sleep resumes when time advances")
    func sleepResumes() async throws {
        let clock = ManualTimeSource(start: Fixtures.baseDate)
        let task = Task {
            try await clock.sleep(for: .seconds(60))
            return clock.now()
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        clock.advance(bySeconds: 60)
        let resumed = try await task.value
        #expect(resumed == Fixtures.baseDate.addingTimeInterval(60))
    }

    @Test("A cancelled sleep throws")
    func cancel() async throws {
        let clock = ManualTimeSource(start: Fixtures.baseDate)
        let task = Task {
            try await clock.sleep(for: .seconds(60))
        }
        try await Task.sleep(nanoseconds: 10_000_000)
        clock.cancelAll()
        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}

@Suite("File store")
struct FileStoreTests {
    @Test("Round trip preserves the values")
    func roundTrip() throws {        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heatglance-tests-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent("ignore.json")
        let list = IgnoreList(entries: [
            IgnoreEntry(kind: .rule, value: "disk_free", label: "Disk", expiresAt: nil)
        ])
        try JSONFileStore.save(list, to: url)
        let loaded = try JSONFileStore.load(IgnoreList.self, from: url)
        #expect(loaded?.entries.count == 1)
        #expect(loaded?.entries.first?.kind == .rule)
    }

    @Test("A missing file returns nothing")
    func missingFile() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("missing-\(UUID().uuidString).json")
        #expect(try JSONFileStore.load(IgnoreList.self, from: url) == nil)
    }

    @Test("Multi word keys survive the round trip")
    func historyRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("heatglance-history-\(UUID().uuidString)", isDirectory: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let url = directory.appendingPathComponent("history.json")
        var store = HistoryStore()
        store.record(Fixtures.sample(groups: [Fixtures.group(cpu: 42)]))
        try JSONFileStore.save(store, to: url)
        let loaded = try JSONFileStore.load(HistoryStore.self, from: url)
        #expect(loaded?.points.count == 1)
        #expect(loaded?.points.first?.systemCPUPercent == 5)
        #expect(loaded?.points.first?.worstGroupCPU == 42)
    }
}
