import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct CleanupView: View {
    @Environment(Monitor.self) private var monitor
    @State private var measurements: [String: CacheMeasurement] = [:]
    @State private var isMeasuring = false
    @State private var messages: [String: String] = [:]
    @State private var busyItemID: String?
    @State private var snapshotMessage: String?

    private let catalog = CacheCatalog()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(catalog.items) { item in
                    itemRow(item)
                }
            }
            HStack {
                Text("Only folders HeatGlance knows. Nothing else is touched.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(refreshTitle) {
                    Task { await measureAll() }
                }
                .disabled(isMeasuring)
            }
            .padding(10)
            snapshotSection
        }
        .task {
            await measureAll()
            monitor.loadSnapshots()
        }
    }

    @ViewBuilder
    private var snapshotSection: some View {
        Divider()
        VStack(alignment: .leading, spacing: 4) {
            Text("Time Machine local snapshots")
                .font(.caption.bold())
            if monitor.snapshots.isEmpty {
                Text("None. They appear when Time Machine backs up.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let snapshotMessage {
                Text(snapshotMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            ForEach(monitor.snapshots) { snapshot in
                HStack {
                    Text(snapshot.date)
                        .font(.caption.monospacedDigit())
                    Spacer()
                    Button("Delete") {
                        monitor.deleteSnapshot(snapshot)
                        snapshotMessage = "Deleting local snapshots needs administrator rights. macOS asks for the password when the helper is installed."
                    }
                    .controlSize(.mini)
                }
            }
        }
        .padding(10)
    }

    private func itemRow(_ item: CacheItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.body)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let message = messages[item.id] {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            Spacer()
            sizeView(for: item)
                .frame(width: 100, alignment: .trailing)
            Button(busyItemID == item.id ? "Working…" : "Clean") {
                clean(item)
            }
            .disabled(busyItemID != nil || !canClean(item))
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sizeView(for item: CacheItem) -> some View {
        let measurement = measurements[item.id] ?? .measuring
        if measurement == .measuring {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(sizeText(measurement))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private var refreshTitle: String {
        if isMeasuring {
            return "Measuring…"
        }
        return "Refresh sizes"
    }

    private func sizeText(_ measurement: CacheMeasurement) -> String {
        switch measurement {
        case let .size(bytes, isUpperBound):
            if isUpperBound {
                return "Up to " + ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
            }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .empty:
            return "Empty"
        case .notInstalled:
            return "Not installed"
        case .notRunning:
            return "Not running"
        case .unknown:
            return "Unknown"
        case .measuring:
            return "Measuring"
        }
    }

    private func canClean(_ item: CacheItem) -> Bool {
        (measurements[item.id] ?? .measuring).canClean
    }

    private func measureAll() async {
        guard !isMeasuring else {
            return
        }
        isMeasuring = true
        for item in catalog.items {
            measurements[item.id] = .measuring
        }
        await withTaskGroup(of: (String, CacheMeasurement).self) { group in
            for item in catalog.items {
                let id = item.id
                let source = item.size
                group.addTask {
                    (id, await CacheMeasurer.measure(source))
                }
            }
            for await (id, measurement) in group {
                measurements[id] = measurement
            }
        }
        isMeasuring = false
    }

    private func measure(_ item: CacheItem) async {
        measurements[item.id] = .measuring
        measurements[item.id] = await CacheMeasurer.measure(item.size)
    }

    private func clean(_ item: CacheItem) {
        busyItemID = item.id
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CacheCleaner.clean(item)
            }.value
            messages[item.id] = result.message
            busyItemID = nil
            await measure(item)
        }
    }
}
