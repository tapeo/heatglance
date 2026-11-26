import SwiftUI

import HeatGlanceCore
import HeatGlanceSystem

struct CleanupView: View {
    @State private var sizes: [String: Int64] = [:]
    @State private var messages: [String: String] = [:]
    @State private var busyItemID: String?

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
                Button("Refresh sizes") {
                    Task { await measureAll() }
                }
            }
            .padding(10)
        }
        .task { await measureAll() }
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
            Text(sizeText(for: item))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .trailing)
            Button(busyItemID == item.id ? "Working…" : "Clean") {
                clean(item)
            }
            .disabled(busyItemID != nil)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func sizeText(for item: CacheItem) -> String {
        guard let path = item.path else {
            return item.command == nil ? "" : "Available"
        }
        guard let size = sizes[item.id] else {
            return "—"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func measureAll() async {
        for item in catalog.items {
            guard let path = item.path else {
                continue
            }
            let measured = await Task.detached(priority: .utility) {
                CacheSizer.sizeOnDisk(ofPath: path)
            }.value
            if let measured {
                sizes[item.id] = measured
            }
        }
    }

    private func clean(_ item: CacheItem) {
        busyItemID = item.id
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                CacheCleaner.clean(item)
            }.value
            messages[item.id] = result.message
            busyItemID = nil
            await measureAll()
        }
    }
}
