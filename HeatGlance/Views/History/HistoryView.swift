import SwiftUI

struct HistoryView: View {
    @Environment(Monitor.self) private var monitor

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Spacer()
                exportMenu
            }
            TabView {
                HistoryChartView()
                    .tabItem { Label("Chart", systemImage: "chart.xyaxis.line") }
                HistoryEventsView()
                    .tabItem { Label("Events", systemImage: "list.bullet") }
                WeeklyReportView()
                    .tabItem { Label("This week", systemImage: "calendar") }
            }
        }
        .padding()
        .frame(minWidth: 640, minHeight: 560)
    }

    private var exportMenu: some View {
        Menu("Export") {
            Button("Copy events as text") {
                HistoryExporter.copyEvents(monitor.eventLog.events)
            }
            Divider()
            Button("Save events as CSV…") {
                HistoryExporter.saveEvents(monitor.eventLog.events)
            }
            Button("Save minutes as CSV…") {
                HistoryExporter.saveMinutes(monitor.history.points)
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
