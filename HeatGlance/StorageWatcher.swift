import Foundation

import HeatGlanceCore
import HeatGlanceSystem

@MainActor
final class StorageWatcher {
    private static let fileName = "storage-scans.json"
    private static let growthMinimumBytes: Int64 = 5 * 1_073_741_824

    private let notifier: Notifier
    private let settings: AppSettingsStore
    private var state = StorageScanState()
    private var isScanningFiles = false
    private var isMeasuringFolders = false

    init(notifier: Notifier, settings: AppSettingsStore) {
        self.notifier = notifier
        self.settings = settings
        if let stored = try? JSONFileStore.load(StorageScanState.self, from: SupportDirectory.url(file: Self.fileName)) {
            state = stored
        }
    }

    func handle(now: Date) {
        if state.isFileScanDue(at: now) && !isScanningFiles {
            state.lastFileScanAt = now
            save()
            scanLargeFiles()
        }
        if state.isFolderMeasureDue(at: now) && !isMeasuringFolders {
            state.lastFolderMeasureAt = now
            save()
            measureFolders()
        }
    }

    private func scanLargeFiles() {
        isScanningFiles = true
        let threshold = Int64(settings.largeFileThresholdGB * 1_073_741_824)
        let excluded = currentExclusions()
        Task {
            let paths = await Task.detached(priority: .utility) {
                let folders = WatchedFolders.allowed(hasFullDiskAccess: FullDiskAccess.isGranted())
                return LargeFileWatch.scan(minimumBytes: threshold, folders: folders, excluded: excluded).map(\.path)
            }.value
            let fresh = state.recordLargeFiles(paths)
            save()
            isScanningFiles = false
            notifyLargeFiles(fresh)
        }
    }

    private func notifyLargeFiles(_ paths: [String]) {
        for path in paths.prefix(3) {
            notifier.send(
                NotificationPayload(
                    category: .fileAlert,
                    title: "Large file: \((path as NSString).lastPathComponent)",
                    body: "\((path as NSString).deletingLastPathComponent) holds a file larger than \(Int(settings.largeFileThresholdGB)) GB.",
                    userInfo: ["path": path],
                    identifier: "heatglance.file.\(path.hashValue)"
                )
            )
        }
    }

    private func measureFolders() {
        isMeasuringFolders = true
        let excluded = currentExclusions()
        Task {
            let measurements = await Task.detached(priority: .background) {
                let folders = WatchedFolders.allowed(hasFullDiskAccess: FullDiskAccess.isGranted())
                return FolderGrowth.measure(folders, excluded: excluded)
            }.value
            let growth = StorageScanState.growth(
                previous: state.folderMeasurements,
                current: measurements,
                minimumBytes: Self.growthMinimumBytes
            )
            state.folderMeasurements = measurements
            save()
            isMeasuringFolders = false
            for entry in growth.prefix(3) {
                notifier.send(
                    NotificationPayload(
                        category: .fileAlert,
                        title: "\((entry.path as NSString).lastPathComponent) grew a lot",
                        body: "It grew by \(Int(Double(entry.bytes) / 1_073_741_824)) GB since the last check.",
                        userInfo: ["path": entry.path],
                        identifier: "heatglance.growth.\(entry.path.hashValue).\(Int(Date().timeIntervalSince1970))"
                    )
                )
            }
        }
    }

    private func currentExclusions() -> ExcludedFolders {
        ExcludedFolders(rawPaths: settings.excludedFolders, home: NSHomeDirectory())
    }

    private func save() {
        try? JSONFileStore.save(state, to: SupportDirectory.url(file: Self.fileName))
    }
}
