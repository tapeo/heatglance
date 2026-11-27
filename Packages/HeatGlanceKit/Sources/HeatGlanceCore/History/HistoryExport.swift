import Foundation

public enum HistoryExport {
    public static func pointsCSV(_ points: [HistoryPoint], timeZone: TimeZone = .current) -> String {
        let header = "time,thermal,memory_pressure,cpu_percent,temperature_c,swap_gb,disk_free_gb,away,paused_apps,worst_app,worst_app_cpu_percent"
        let formatter = isoFormatter(timeZone: timeZone)
        var lines = [header]
        for point in points {
            let fields = [
                formatter.string(from: point.minute),
                point.thermal.title,
                point.memoryPressure.title,
                String(format: "%.1f", point.systemCPUPercent),
                optionalNumber(point.temperatureCelsius),
                String(format: "%.1f", Double(point.swapUsedBytes) / 1_073_741_824),
                String(format: "%.1f", Double(point.diskAvailableBytes) / 1_073_741_824),
                awayField(point.isAway),
                optionalInteger(point.pausedApps),
                point.worstGroupName ?? "",
                String(format: "%.1f", point.worstGroupCPU),
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    public static func eventsCSV(_ events: [HistoryEvent], timeZone: TimeZone = .current) -> String {
        let header = "time,event,app,title,value,notified,detail"
        let formatter = isoFormatter(timeZone: timeZone)
        var lines = [header]
        for event in events {
            let fields = [
                formatter.string(from: event.date),
                event.kind.title,
                event.appName ?? "",
                event.title,
                event.value ?? "",
                notifiedField(event.notified),
                event.detail ?? "",
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    public static func eventsText(_ events: [HistoryEvent], timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        return events.map { event in
            var line = "\(formatter.string(from: event.date))  \(event.kind.title): \(event.title)"
            if let appName = event.appName {
                line += " (\(appName))"
            }
            if let value = event.value {
                line += ", \(value)"
            }
            if event.notified == true {
                line += ", notified"
            }
            return line
        }
        .joined(separator: "\n")
    }

    private static func isoFormatter(timeZone: TimeZone) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = timeZone
        return formatter
    }

    private static func optionalNumber(_ value: Double?) -> String {
        guard let value else {
            return ""
        }
        return String(format: "%.1f", value)
    }

    private static func optionalInteger(_ value: Int?) -> String {
        guard let value else {
            return ""
        }
        return "\(value)"
    }

    private static func awayField(_ isAway: Bool?) -> String {
        guard let isAway else {
            return ""
        }
        if isAway {
            return "yes"
        }
        return "no"
    }

    private static func notifiedField(_ notified: Bool?) -> String {
        guard notified == true else {
            return ""
        }
        return "yes"
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
