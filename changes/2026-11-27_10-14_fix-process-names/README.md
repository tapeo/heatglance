## Change

Process names in "Top processes by CPU" rendered as replacement characters, control bytes and NULs for processes without a bundle identifier, because the `pbi_comm` slice outlived the `withUnsafeBytes` closure it pointed into.

## Decisions

- In `ProcessReader.snapshot(for:now:currentUserID:)` the `String` is built inside the `withUnsafeBytes(of: info.pbi_comm)` closure. Never move `String(decoding:)` or `prefix { $0 != 0 }` back outside: the slice references a temporary copy of the tuple, so reading it afterwards is undefined behavior.
- Do not switch to `String(cString:)` on `pbi_comm`: the field can fill all `MAXCOMLEN` bytes and carry no NUL terminator.
- No other `withUnsafe*` call in the repo lets a pointer or slice escape its closure; do not go looking for more fixes there.
- `history.json` and `trends.json` on the client still hold corrupted names written before the fix. They expire with the seven-day retention; no migration was added.
- The same corrupted names reached `KnowledgeBase.match(groupID:processName:)`, so name-based rules could miss non-bundle processes. The fix restores those matches without other changes.

## Files

- `Packages/HeatGlanceKit/Sources/HeatGlanceSystem/Processes/ProcessReader.swift` (modified)

## Verification

- `./test.sh` (swift test of HeatGlanceKit plus xcodegen) and `./build.sh` on the client: both succeeded.
- `./run.sh` relaunched the app on the client; panel names need a visual check.
