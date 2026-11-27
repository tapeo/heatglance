import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("History series")
struct HistorySeriesTests {
    let start = Fixtures.baseDate

    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    func point(
        at date: Date,
        cpu: Double = 10,
        disk: Int64 = 500_000_000_000,
        away: Bool? = nil,
        paused: Int? = nil,
        worstName: String? = "Example",
        worstCPU: Double = 0
    ) -> HistoryPoint {
        HistoryPoint(
            minute: date,
            thermal: .nominal,
            memoryPressure: .normal,
            systemCPUPercent: cpu,
            swapUsedBytes: 0,
            diskAvailableBytes: disk,
            worstGroupName: worstName,
            worstGroupCPU: worstCPU,
            isAway: away,
            pausedApps: paused
        )
    }

    @Test("Six hours gives one bucket per point and drops older points")
    func sixHours() {
        let now = Date(timeIntervalSince1970: 1_700_000_040)
        let points = [
            point(at: now.addingTimeInterval(-5 * 3600)),
            point(at: now.addingTimeInterval(-2 * 3600)),
            point(at: now.addingTimeInterval(-5 * 60)),
            point(at: now.addingTimeInterval(-7 * 3600)),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .recent(.sixHours), now: now, calendar: calendar)
        #expect(buckets.count == 3)
        #expect(buckets.allSatisfy { $0.end.timeIntervalSince($0.start) == 60 })
    }

    @Test("Seven days aggregates thirty minutes into one bucket")
    func weekAggregation() throws {
        let anchor = Date(timeIntervalSince1970: 1_699_999_200)
        var points: [HistoryPoint] = []
        for index in 0..<30 {
            let date = anchor.addingTimeInterval(Double(30 + index * 60))
            var cpu = 10 + Double(index)
            var worstCPU = Double(index)
            if index == 15 {
                cpu = 40
                worstCPU = 100
            }
            points.append(
                point(
                    at: date,
                    cpu: cpu,
                    disk: 900_000_000_000 - Int64(index) * 1_000_000_000,
                    away: index == 15,
                    worstName: "App \(index)",
                    worstCPU: worstCPU
                )
            )
        }
        let now = anchor.addingTimeInterval(1770)

        let buckets = HistorySeries.buckets(points: points, window: .recent(.week), now: now, calendar: calendar)
        #expect(buckets.count == 1)
        let bucket = try #require(buckets.first)
        #expect(bucket.systemCPUPercent == 40)
        #expect(bucket.diskAvailableBytes == 871_000_000_000)
        #expect(bucket.worstGroupName == "App 15")
        #expect(bucket.isAway)
    }

    @Test("A past day uses one minute buckets and only its own points")
    func pastDay() {
        let today = calendar.startOfDay(for: start)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let before = calendar.date(byAdding: .day, value: -2, to: today)!
        let points = [
            point(at: yesterday.addingTimeInterval(8 * 3600)),
            point(at: yesterday.addingTimeInterval(8 * 3600 + 600)),
            point(at: today.addingTimeInterval(60)),
            point(at: before.addingTimeInterval(3600)),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .day(yesterday), now: start, calendar: calendar)
        #expect(buckets.count == 2)
        #expect(buckets.allSatisfy { $0.end.timeIntervalSince($0.start) == 60 })
        #expect(buckets.allSatisfy { $0.start >= yesterday && $0.end <= today })
    }

    @Test("Seven days are available, today first")
    func availableDays() {
        let days = HistoryWindow.availableDays(now: start, calendar: calendar)
        #expect(days.count == 7)
        #expect(days.first == calendar.startOfDay(for: start))
        #expect(days == days.sorted(by: >))
        #expect(days.allSatisfy { calendar.startOfDay(for: $0) == $0 })
    }

    @Test("A gap opens a new segment")
    func gap() {
        let now = Date(timeIntervalSince1970: 1_700_000_040)
        let points = [
            point(at: now.addingTimeInterval(-180 * 60)),
            point(at: now.addingTimeInterval(-179 * 60)),
            point(at: now.addingTimeInterval(-178 * 60)),
            point(at: now.addingTimeInterval(-1 * 60)),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .recent(.sixHours), now: now, calendar: calendar)
        #expect(buckets.count == 4)
        #expect(buckets.map(\.segment) == [0, 0, 0, 1])
    }

    @Test("Spans join consecutive away buckets")
    func awaySpans() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_040)
        let points = [
            point(at: now.addingTimeInterval(-4 * 60), away: true),
            point(at: now.addingTimeInterval(-3 * 60), away: true),
            point(at: now.addingTimeInterval(-2 * 60), away: true),
            point(at: now.addingTimeInterval(-1 * 60), away: false),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .recent(.sixHours), now: now, calendar: calendar)
        try #require(buckets.count == 4)
        let spans = HistorySeries.spans(buckets) { $0.isAway }
        #expect(spans.count == 1)
        #expect(spans.first?.start == buckets.first?.start)
        #expect(spans.first?.end == buckets[2].end)
    }

    @Test("Spans separate distinct groups and segments")
    func spanGroups() {
        let now = Date(timeIntervalSince1970: 1_700_000_040)
        let points = [
            point(at: now.addingTimeInterval(-6 * 3600), away: true),
            point(at: now.addingTimeInterval(-3 * 60), away: true),
            point(at: now.addingTimeInterval(-2 * 60), away: true),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .recent(.sixHours), now: now, calendar: calendar)
        let spans = HistorySeries.spans(buckets) { $0.isAway }
        #expect(spans.count == 2)
        #expect(buckets.last?.segment == 1)
    }

    @Test("The bucket under a date is found and a gap gives nothing")
    func bucketAt() {
        let now = Date(timeIntervalSince1970: 1_700_000_040)
        let points = [
            point(at: now.addingTimeInterval(-120)),
            point(at: now.addingTimeInterval(-60)),
        ]

        let buckets = HistorySeries.buckets(points: points, window: .recent(.sixHours), now: now, calendar: calendar)
        #expect(HistorySeries.bucket(at: now.addingTimeInterval(-90), in: buckets)?.start == now.addingTimeInterval(-120))
        #expect(HistorySeries.bucket(at: now.addingTimeInterval(30), in: buckets) == nil)
    }
}
