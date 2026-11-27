## Change

"This week" showed memory in raw bytes labelled GB and CPU as unitless "points". CPU now accumulates core hours from the real sample interval, memory is formatted from bytes and aggregated per week as a peak.

## Decisions

- CPU accumulator unit is core hours: `cpuPercent / 100 * interval / 3600`. The interval comes from `TrendsEngine.lastSummarySampleDate`, so it follows the actual sampling (2, 5 or 10 s) instead of a fixed `/60`.
- `takeSummaryInterval(upTo:)` returns nil when the gap is not in `(0, 120]`. First sample after launch and sleep or paused gaps therefore skip the CPU accumulation but still advance `lastSummarySampleDate`. Do not derive the interval from the configured sampling interval: `Sampler` changes it at runtime.
- `lastSummarySampleDate` is an optional stored property of `TrendsEngine`, encoded in `trends.json` and decoded with the synthesized `decodeIfPresent`. Keep it optional and do not add a manual `init(from:)`: existing files must keep loading.
- `WeeklyReport` memory values are daily peaks, so `DailySummaryStore.aggregate` takes a `combine` closure: sum for CPU and writes, `max` for memory. Previous-week totals use the same combiner, so the change percentage compares peaks with peaks.
- `topWrites` stays in GB (the accumulator already divides by 1 073 741 824). The weekly value remains a sum of daily maxima; that is not the real total written, but it is out of scope here.
- `WeeklyReportView.list` takes `format: @escaping (Double) -> String`, because `ForEach` content is escaping. Memory uses `ByteCountFormatter.string(fromByteCount:countStyle: .memory)`; CPU shows `%.1f` under the header "Top CPU, core hours".
- No migration. Values written before this change keep the old CPU scale. The client's `trends.json` summaries were cleared once (backup in `/tmp` on the client, outside the repository) so the week does not mix the two scales.

## Files

- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Trends/TrendsEngine.swift` (modified)
- `Packages/HeatGlanceKit/Sources/HeatGlanceCore/Trends/DailySummary.swift` (modified)
- `HeatGlance/Views/History/WeeklyReportView.swift` (modified)
- `Packages/HeatGlanceKit/Tests/HeatGlanceCoreTests/TrendsTests.swift` (modified)

## Verification

- `./test.sh` on the client: 110 tests pass, including "CPU accumulates in core hours from the sample interval" and "Weekly memory takes the daily peak, not the sum".
- `./build.sh` and `./run.sh` on the client: build succeeded, app relaunched. The panel needs a visual check of "This week".
