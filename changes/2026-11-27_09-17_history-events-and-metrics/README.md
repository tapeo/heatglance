## Change

History now keeps a searchable event log, a multi-metric chart with away and paused bands, one-minute day views, CSV and text export, and seven days of retention for points and events.

## Decisions

- History points and events both keep seven days: `HistoryStore.capacity` is 10 080, `HistoryEventLog.retention` is 7 days with a 5 000 event cap.
- `HistoryPoint` gained three optional fields (`temperatureCelsius`, `isAway`, `pausedApps`). Decoding relies on the synthesized `decodeIfPresent`; never add a manual `init(from:)` or old `history.json` files stop loading, and `Monitor.loadHistory` uses `try?`, so the next save would overwrite them with an empty store.
- The event log lives in `events.json` next to `history.json` in the HeatGlance support folder. Events save immediately on append; points still save every ten minutes.
- One row per fact. Alerts, protection pauses, and the welcome back notification pass `logsAsEvent: false` and mark the event with `notified: true`; every other notification goes through `Notifier.onSend` and becomes a Notification row. Do not add a Notification row for the same event in Monitor.
- Protection state is sampled, not pushed: `checkProtectionMode(now:)` compares `ProtectionSettings.mode(at:)` on every sample and in `applySettings()`. The toggle in Settings, `toggleProtection`, `pauseProtection`, `resumeProtectionNow` and the automatic pause expiry all land there, so do not record protection events from those methods.
- `resume(groupID:)` is the user action; `evaluateGuard` calls `resumeGroup(groupID:)` directly so automatic resumes never look like user actions.
- `HistoryWindow.day(Date)` keeps the passed date, but `interval(now:calendar:)` and `dayStart(calendar:)` normalize to the start of the day. Never add 86 400 seconds to walk days: the DST change makes days of 23 or 25 hours.
- Bucket starts are epoch-aligned like `HistoryPoint.minute(of:)`, and segments break when two bucket starts are more than `2 * bucketSeconds` apart. Removing segments makes the chart draw straight lines across hours when the Mac slept.
- The chart recomputes buckets in `.task(id:)` from the window and the last point minute. Never compute buckets in `body`: hover selection re-evaluates it on pointer movement.
- Export always covers the full seven days, not the chart window.
- `Monitor.swift` was split into `Monitor+Persistence.swift`, `Monitor+Notifications.swift` and `Monitor+Protection.swift`; members used from the extensions are internal, not private.

## Files

- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryStore.swift` (modified)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryEvent.swift` (created)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryEventValue.swift` (created)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistorySeries.swift` (created)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/History/HistoryExport.swift` (created)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Protection/ProtectionSettings.swift` (modified)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Rules/RuleDefinition.swift` (modified)
- `Packages/HeatGlanceKit/Sources/HeatGlanceSystem/Notifications/NotificationCategories.swift` (modified)
- `Packages/HeatGlanceKit/Sources/HeatGlanceSystem/Notifications/Notifier.swift` (modified)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/Fixtures.swift` (modified)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryStoreTests.swift` (created)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryEventTests.swift` (created)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistorySeriesTests.swift` (created)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/HistoryExportTests.swift` (created)
- `HeatGlance/Monitor.swift` (modified)
- `HeatGlance/Monitor+Persistence.swift` (created)
- `HeatGlance/Monitor+Notifications.swift` (created)
- `HeatGlance/Monitor+Protection.swift` (created)
- `HeatGlance/Views/HistoryView.swift` (deleted)
- `HeatGlance/Views/History/HistoryView.swift` (created)
- `HeatGlance/Views/History/HistoryChartView.swift` (created)
- `HeatGlance/Views/History/HistoryWindowPicker.swift` (created)
- `HeatGlance/Views/History/HistoryMetricChart.swift` (created)
- `HeatGlance/Views/History/HistoryDetailView.swift` (created)
- `HeatGlance/Views/History/HistoryEventsView.swift` (created)
- `HeatGlance/Views/History/WeeklyReportView.swift` (created)
- `HeatGlance/Views/History/HistoryExporter.swift` (created)
- `HeatGlance/HeatGlanceApp.swift` (modified)
- `README.md` (modified)

## Verification

- `./test.sh` on the client: 108 tests in 19 suites passed, including History store, History events, History series and History export.
- `./build.sh` on the client: `BUILD SUCCEEDED`. The remaining warnings are older and sit in files this change does not touch (`AppDelegate.swift`, `ProcessReader.swift`, `Sampler.swift`, `SystemInfoReaders.swift`).
- Deviations from the plan: `LineMark(x:y:series:)` replaces a `.series()` modifier that does not exist; the chart x domain lives in `@State`; a third extension, `Monitor+Protection.swift`, was added after review to keep `Monitor.swift` under the size limit; the review also fixed the `memory_critical` value and the duplicate ids of the chart bands.
- Still to check by hand on the Mac: an existing `history.json` loads, hover stays smooth on a full day with the window open (the body redraws every sample; the review has a `TimelineView` fallback ready), the five panels line up, each alert shows once, and the CSV opens in Numbers.
