import Foundation
import Testing

@testable import HeatGlanceCore

private let gigabyte: Int64 = 1_073_741_824

@Suite("Storage scans")
struct StorageScanTests {
    @Test("Without full disk access only unprotected folders are watched")
    func withoutFullDiskAccess() {
        let allowed = WatchedFolders.allowed(hasFullDiskAccess: false)
        #expect(allowed.map(\.relativePath) == ["Library/Developer"])
    }

    @Test("No folder covers other apps' data")
    func noContainers() {
        for folder in WatchedFolders.all {
            #expect(folder.relativePath != "Library")
            #expect(!folder.relativePath.contains("Containers"))
        }
    }

    @Test("With full disk access every folder is watched")
    func withFullDiskAccess() {
        #expect(WatchedFolders.allowed(hasFullDiskAccess: true) == WatchedFolders.all)
    }

    @Test("A scan is due after its interval or when the clock moves back")
    func dueDates() {
        let now = Fixtures.baseDate
        #expect(StorageScanState().isFileScanDue(at: now))
        #expect(!StorageScanState(lastFileScanAt: now.addingTimeInterval(-600)).isFileScanDue(at: now))
        #expect(StorageScanState(lastFileScanAt: now.addingTimeInterval(-1860)).isFileScanDue(at: now))
        #expect(StorageScanState(lastFileScanAt: now.addingTimeInterval(60)).isFileScanDue(at: now))
        #expect(!StorageScanState(lastFolderMeasureAt: now.addingTimeInterval(-82_800)).isFolderMeasureDue(at: now))
        #expect(StorageScanState(lastFolderMeasureAt: now.addingTimeInterval(-86_400)).isFolderMeasureDue(at: now))
    }

    @Test("Only new large files are reported, up to the limit")
    func recordLargeFiles() {
        var state = StorageScanState()
        #expect(state.recordLargeFiles(["/a", "/b"]) == ["/a", "/b"])
        #expect(state.recordLargeFiles(["/b", "/c"]) == ["/c"])

        var many = StorageScanState()
        var paths: [String] = []
        for index in 0...500 {
            paths.append("/file\(index)")
        }
        _ = many.recordLargeFiles(paths)
        #expect(many.notifiedLargeFiles.count == 500)
        #expect(many.notifiedLargeFiles.first == "/file1")
    }

    @Test("Growth needs a previous measure and the minimum size")
    func growth() throws {
        let previous = [
            FolderMeasurement(path: "/Users/test/Downloads", bytes: 10 * gigabyte, date: Fixtures.baseDate),
            FolderMeasurement(path: "/Users/test/Desktop", bytes: 10 * gigabyte, date: Fixtures.baseDate),
        ]
        let current = [
            FolderMeasurement(path: "/Users/test/Downloads", bytes: 16 * gigabyte, date: Fixtures.baseDate),
            FolderMeasurement(path: "/Users/test/Desktop", bytes: 14 * gigabyte, date: Fixtures.baseDate),
            FolderMeasurement(path: "/Users/test/Movies", bytes: 100 * gigabyte, date: Fixtures.baseDate),
        ]
        let changes = StorageScanState.growth(previous: previous, current: current, minimumBytes: 5 * gigabyte)
        #expect(changes.count == 1)
        let grown = try #require(changes.first)
        #expect(grown.path == "/Users/test/Downloads")
        #expect(grown.bytes == 6 * gigabyte)
    }

    @Test("A saved state round trips through JSON")
    func roundTrip() throws {
        let state = StorageScanState(
            lastFileScanAt: Fixtures.baseDate,
            lastFolderMeasureAt: Fixtures.baseDate.addingTimeInterval(3600),
            notifiedLargeFiles: ["/a"],
            folderMeasurements: [FolderMeasurement(path: "/Users/test/Downloads", bytes: 10, date: Fixtures.baseDate)]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let data = try encoder.encode(state)
        let decoded = try decoder.decode(StorageScanState.self, from: data)
        #expect(decoded == state)
    }
}

@Suite("Excluded folders")
struct ExcludedFoldersTests {
    let home = "/Users/test"

    @Test("Entries are normalized")
    func normalization() {
        let excluded = ExcludedFolders(
            rawPaths: ["~/Downloads/VMs", "~", "/Volumes/Data/", "  ~/Movies  ", "", "Downloads", "~other/Downloads", "/"],
            home: home
        )
        #expect(excluded.paths == [
            "/Users/test/Downloads/VMs",
            "/Users/test",
            "/Volumes/Data",
            "/Users/test/Movies",
        ])
    }

    @Test("Duplicates after normalization become one entry")
    func duplicates() {
        let excluded = ExcludedFolders(rawPaths: ["~/Movies", "/Users/test/Movies/"], home: home)
        #expect(excluded.paths == ["/Users/test/Movies"])
    }

    @Test("A folder and everything below it are excluded")
    func contains() {
        let excluded = ExcludedFolders(rawPaths: ["~/Downloads"], home: home)
        #expect(excluded.contains("/Users/test/Downloads"))
        #expect(excluded.contains("/Users/test/Downloads/a/b"))
        #expect(!excluded.contains("/Users/test/DownloadsOld"))
    }

    @Test("Inside returns only the entries strictly below a root")
    func inside() {
        let excluded = ExcludedFolders(
            rawPaths: ["~/Downloads/VMs", "~/Library/Developer/CoreSimulator", "/Volumes/Data"],
            home: home
        )
        #expect(excluded.inside("/Users/test/Downloads") == ["/Users/test/Downloads/VMs"])
        #expect(excluded.inside("/Users/test/Library/Developer") == ["/Users/test/Library/Developer/CoreSimulator"])
        #expect(excluded.inside("/Users/test/Downloads/VMs").isEmpty)
    }
}
