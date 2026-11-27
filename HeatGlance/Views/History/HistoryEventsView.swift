import Foundation
import SwiftUI

import HeatGlanceCore

struct HistoryEventsView: View {
    @Environment(Monitor.self) private var monitor
    @State private var category: HistoryEventCategory?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Category", selection: $category) {
                Text("All").tag(HistoryEventCategory?.none)
                ForEach(HistoryEventCategory.allCases) { item in
                    Text(item.title).tag(Optional(item))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()

            if events.isEmpty {
                Text("Events appear here as HeatGlance sees them.")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                List {
                    ForEach(days, id: \.self) { day in
                        Section(dayTitle(day)) {
                            ForEach(eventsByDay[day] ?? []) { event in
                                row(event)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private var events: [HistoryEvent] {
        let all = monitor.eventLog.events.sorted { $0.date > $1.date }
        guard let category else {
            return all
        }
        return all.filter { $0.kind.category == category }
    }

    private var eventsByDay: [Date: [HistoryEvent]] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.date) }
    }

    private var days: [Date] {
        eventsByDay.keys.sorted(by: >)
    }

    private func row(_ event: HistoryEvent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(timeText(event.date))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Image(systemName: icon(event.kind.category))
                .font(.caption)
                .foregroundStyle(color(event.kind.category))
            Text(event.title)
                .lineLimit(1)
            if let appName = event.appName {
                Text(appName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 6)
            if let value = event.value {
                Text(value)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if event.notified == true {
                Image(systemName: "bell")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .help("Notification sent")
            }
        }
        .help(event.detail ?? "")
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func dayTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: day)
    }

    private func icon(_ category: HistoryEventCategory) -> String {
        switch category {
        case .alerts:
            return "exclamationmark.triangle"
        case .notifications:
            return "bell"
        case .protection:
            return "shield"
        case .actions:
            return "hand.raised"
        case .presence:
            return "person"
        }
    }

    private func color(_ category: HistoryEventCategory) -> Color {
        switch category {
        case .alerts:
            return .orange
        case .notifications, .presence:
            return .secondary
        case .protection:
            return .blue
        case .actions:
            return .primary
        }
    }
}
