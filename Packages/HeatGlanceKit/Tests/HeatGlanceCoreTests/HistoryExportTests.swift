import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("History export")
struct HistoryExportTests {
    let start = Fixtures.baseDate

    var utc: TimeZone {
        TimeZone(secondsFromGMT: 0) ?? .current
    }

    @Test("Points export with a header and one row")
    func pointsCSV() {
        let point = HistoryPoint(
            minute: start,
            thermal: .serious,
            memoryPressure: .warning,
            systemCPUPercent: 42,
            swapUsedBytes: 6_657_000_000,
            diskAvailableBytes: 100_000_000_000,
            worstGroupName: "Example",
            worstGroupCPU: 182,
            temperatureCelsius: 92,
            isAway: true,
            pausedApps: 2
        )
        let lines = HistoryExport.pointsCSV([point], timeZone: utc)
            .split(separator: "\n")
            .map(String.init)
        #expect(lines.count == 2)
        #expect(lines[0] == "time,thermal,memory_pressure,cpu_percent,temperature_c,swap_gb,disk_free_gb,away,paused_apps,worst_app,worst_app_cpu_percent")
        #expect(lines[1] == "2023-11-14T22:13:20Z,Serious,Warning,42.0,92.0,6.2,93.1,yes,2,Example,182.0")
    }

    @Test("Missing values leave the field empty")
    func emptyFields() {
        let point = HistoryPoint(
            minute: start,
            thermal: .nominal,
            memoryPressure: .normal,
            systemCPUPercent: 5,
            swapUsedBytes: 0,
            diskAvailableBytes: 0,
            worstGroupName: nil,
            worstGroupCPU: 0
        )
        let lines = HistoryExport.pointsCSV([point], timeZone: utc)
            .split(separator: "\n")
            .map(String.init)
        #expect(lines[1] == "2023-11-14T22:13:20Z,Nominal,Normal,5.0,,0.0,0.0,,,,0.0")
    }

    @Test("Commas and quotes in app names are escaped")
    func escaping() {
        let event = HistoryEvent(date: start, kind: .manualQuit, title: "Quit by you", appName: "Foo, \"Bar\"")
        let csv = HistoryExport.eventsCSV([event], timeZone: utc)
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines[0] == "time,event,app,title,value,notified,detail")
        #expect(csv.contains("\"Foo, \"\"Bar\"\"\""))
    }

    @Test("Events export as readable lines")
    func eventsText() {
        let notified = HistoryEvent(
            date: start,
            kind: .alertStarted,
            title: "Mac is getting hot",
            appName: "Example",
            value: "Thermal serious, 92 °C",
            notified: true
        )
        let plain = HistoryEvent(date: start, kind: .protectionOff, title: "Protection turned off")

        #expect(
            HistoryExport.eventsText([notified], timeZone: utc)
                == "2023-11-14 22:13:20  Alert: Mac is getting hot (Example), Thermal serious, 92 °C, notified"
        )
        #expect(
            HistoryExport.eventsText([plain], timeZone: utc)
                == "2023-11-14 22:13:20  Protection off: Protection turned off"
        )
    }
}
