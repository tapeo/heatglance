# HeatGlance

A menu bar monitor for Apple silicon Macs. It watches heat, memory, CPU and disk, says what is going on, and gives you the buttons to stop the cause. It never acts on its own, with one opt-in exception: thermal protection, which pauses the apps that heat the Mac while you are away.

## Requirements

- macOS 14 or later
- Apple silicon
- Xcode 16 or later with XcodeGen (`brew install xcodegen`)

## Build and run

```bash
./build.sh          # Debug build into build/
./run.sh            # build, then open the app
./test.sh           # package tests, then check the project generates
./release.sh        # Developer ID build, notarized DMG into dist/
```

## What it does

- Menu bar icon that changes with the worst active rule.
- Thermal state, memory pressure, swap, CPU and free disk, with the three busiest apps.
- Process actions: suspend, quit, force quit, ignore for an hour.
- Alerts on sustained thresholds, with hysteresis and a cooldown.
- Known culprits explained from a bundled list: Spotlight indexing, kernel_task, Docker, Chrome helpers, Xcode builds.
- Thermal protection: while you are away, it suspends the apps that heat the Mac and resumes them once it cools. Presence comes from the lock screen, display sleep, session changes, idle time, video, microphone and camera. Off by default.
- Cache cleanup for Xcode, Homebrew, npm, pnpm and Docker, plus Time Machine snapshot listing.
- 24 hour history.

## Permissions

- Notifications.
- Full disk access, optional, for folder sizes in protected folders.
- No Apple Events, no accessibility, no privileged helper.

## License

MIT, see `LICENSE`.
