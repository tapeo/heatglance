import Foundation
import Testing

@testable import HeatGlanceCore

@Suite("Trends")
struct TrendsTests {
    @Test("A steady climb is detected as a leak")
    func leakDetected() {
        var detector = LeakDetector()
        let start = Fixtures.baseDate
        for step in 0...36 {
            let date = start.addingTimeInterval(Double(step) * 300)
            let footprint = UInt64(15 + step) * 40 * 1_048_576
            let group = Fixtures.group(footprint: footprint)
            detector.update(groups: [group], now: date)
        }
        let leaks = detector.leaks(now: start.addingTimeInterval(36 * 300))
        #expect(leaks.count == 1)
    }

    @Test("A sawtooth pattern is not a leak")
    func sawtooth() {
        var detector = LeakDetector()
        let start = Fixtures.baseDate
        for step in 0...36 {
            let date = start.addingTimeInterval(Double(step) * 300)
            let baseline: UInt64 = step % 2 == 0 ? 1_400 * 1_048_576 : 700 * 1_048_576
            detector.update(groups: [Fixtures.group(footprint: baseline)], now: date)
        }
        #expect(detector.leaks(now: start.addingTimeInterval(36 * 300)).isEmpty)
    }

    @Test("Disk writes sum deltas and survive a restart of the counter")
    func diskWrites() {
        var tracker = DiskWriteTracker(dayStart: Calendar.current.startOfDay(for: Fixtures.baseDate))
        var group = Fixtures.group(written: 0)
        tracker.update(groups: [group], now: Fixtures.baseDate)
        group = Fixtures.group(written: 3_000_000_000)
        tracker.update(groups: [group], now: Fixtures.baseDate.addingTimeInterval(300))
        #expect(tracker.apps["com.example.app"]?.dayBytes == 3_000_000_000)

        group = Fixtures.group(written: 1_000_000_000)
        tracker.update(groups: [group], now: Fixtures.baseDate.addingTimeInterval(360))
        #expect(tracker.apps["com.example.app"]?.dayBytes == 4_000_000_000)
    }

    @Test("The day counter resets at midnight")
    func dayReset() {
        let start = Calendar.current.startOfDay(for: Fixtures.baseDate)
        var tracker = DiskWriteTracker(dayStart: start)
        tracker.update(groups: [Fixtures.group(written: 5_000_000_000)], now: start.addingTimeInterval(3600))
        #expect(tracker.apps["com.example.app"]?.dayBytes == 0)
        tracker.update(groups: [Fixtures.group(written: 6_000_000_000)], now: start.addingTimeInterval(3700))
        #expect(tracker.apps["com.example.app"]?.dayBytes == 1_000_000_000)
        tracker.update(groups: [Fixtures.group(written: 1_000_000_000)], now: start.addingTimeInterval(86_400 + 60))
        #expect(tracker.apps["com.example.app"]?.dayBytes == 0)
    }

    @Test("Anomalies need a learned baseline")
    func anomalyNeedsLearning() {
        var store = BaselineStore()
        let group = Fixtures.group(cpu: 100)
        let baseline = store.observe(group: group, now: Fixtures.baseDate)
        #expect(!store.isLearned(baseline, now: Fixtures.baseDate.addingTimeInterval(86_400)))

        let learnedAt = Fixtures.baseDate.addingTimeInterval(8 * 86_400)
        var learned = baseline
        learned.observedMinutes = 200
        store.baselines["com.example.app"] = learned
        let findings = AnomalyDetector().findings(
            groups: [Fixtures.group(cpu: 500)],
            store: store,
            now: learnedAt
        )
        #expect(findings.contains { $0.kind == .cpu })
    }

    @Test("Baselines keep at most the capacity")
    func baselineCapacity() {
        var store = BaselineStore(capacity: 3)
        for index in 0..<6 {
            store.observe(
                group: Fixtures.group(id: "com.example.app\(index)", name: "App \(index)"),
                now: Fixtures.baseDate.addingTimeInterval(Double(index))
            )
        }
        #expect(store.baselines.count == 3)
    }

    @Test("The weekly report aggregates and compares")
    func weeklyReport() {
        var store = DailySummaryStore()
        let today = Fixtures.baseDate
        for offset in 0..<7 {
            let day = today.addingTimeInterval(Double(-offset) * 86_400)
            var summary = store.ensureDay(day)
            summary.topCPU = [AppTotal(groupID: "com.example.app", displayName: "Example", value: 10)]
            summary.thermalSeriousMinutes = 5
            store.update(summary)
        }
        let report = store.week(endingAt: today)
        #expect(report.topCPU.first?.value == 70)
        #expect(report.seriousMinutes == 35)
    }

    @Test("An orphan needs a launchd parent, a bundle path and no running app")
    func orphanClassification() {
        let classifier = OrphanClassifier()
        let group = Fixtures.orphanGroup(path: "/Applications/Foo.app/Contents/Helpers/foo")
        let good = OrphanClassifier.Input(group: group, parentIsLaunchd: true, bundleAppIsRunning: false, isLoginItem: false)
        #expect(classifier.classify(good) != nil)

        let appRunning = OrphanClassifier.Input(group: group, parentIsLaunchd: true, bundleAppIsRunning: true, isLoginItem: false)
        #expect(classifier.classify(appRunning) == nil)

        let loginItem = OrphanClassifier.Input(group: group, parentIsLaunchd: true, bundleAppIsRunning: false, isLoginItem: true)
        #expect(classifier.classify(loginItem) == nil)
    }
}

@Suite("App bundle paths")
struct AppBundlePathTests {
    @Test("The bundle of an executable is the outermost app")
    func containing() {
        #expect(AppBundlePath.containing(executablePath: "/Applications/Foo.app/Contents/Helpers/foo") == "/Applications/Foo.app")
        #expect(AppBundlePath.containing(
            executablePath: "/Applications/Foo.app/Contents/Frameworks/Foo Helper.app/Contents/MacOS/Foo Helper"
        ) == "/Applications/Foo.app")
        #expect(AppBundlePath.containing(executablePath: "/usr/bin/foo") == nil)
    }

    @Test("A helper's app is running only when its bundle is open")
    func isRunning() {
        let path = "/Applications/Foo.app/Contents/Helpers/foo"
        #expect(AppBundlePath.isRunning(executablePath: path, runningBundlePaths: ["/Applications/Foo.app"]))
        #expect(!AppBundlePath.isRunning(executablePath: path, runningBundlePaths: []))
        #expect(!AppBundlePath.isRunning(executablePath: nil, runningBundlePaths: ["/Applications/Foo.app"]))
        #expect(!AppBundlePath.isRunning(executablePath: path, runningBundlePaths: ["/Applications/Foo Pro.app"]))
    }

    @Test("A helper of a closed app is a leftover")
    func closedAppLeftover() {
        let classifier = OrphanClassifier()
        let path = "/Applications/Foo.app/Contents/Helpers/foo"
        let group = Fixtures.orphanGroup(path: path)

        let running = AppBundlePath.isRunning(executablePath: path, runningBundlePaths: [])
        let leftover = OrphanClassifier.Input(group: group, parentIsLaunchd: true, bundleAppIsRunning: running, isLoginItem: false)
        #expect(classifier.classify(leftover) != nil)

        let openApp = AppBundlePath.isRunning(executablePath: path, runningBundlePaths: ["/Applications/Foo.app"])
        let attached = OrphanClassifier.Input(group: group, parentIsLaunchd: true, bundleAppIsRunning: openApp, isLoginItem: false)
        #expect(classifier.classify(attached) == nil)
    }
}

@Suite("Cache catalog")
struct CacheCatalogTests {
    @Test("Every entry has an id, a title and a method")
    func entries() {
        let items = CacheCatalog().items
        #expect(!items.isEmpty)
        #expect(Set(items.map(\.id)).count == items.count)
        for item in items {
            #expect(!item.title.isEmpty)
            #expect(!item.detail.isEmpty)
        }
    }

    @Test("Lookup by id works")
    func lookup() {
        #expect(CacheCatalog().item(id: "derived_data") != nil)
        #expect(CacheCatalog().item(id: "missing") == nil)
    }
}
