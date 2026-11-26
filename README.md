# HeatGlance

A menu bar app for people who leave AI agents working on their Mac and walk away.

I built HeatGlance after an agent left a process in a loop on my Mac while I was away from the screen. The machine stayed hot for an hour before I noticed. If the Mac stays awake with the lid closed, an agent can work for hours with nobody watching, and a loop does not stop by itself.

HeatGlance samples heat, memory, CPU and disk every few seconds, names the app behind a problem, and, if you leave it on, pauses the apps that heat the Mac while you are away and resumes them once it cools. It is built for the hours when nobody is managing the Mac.

<img src="docs/menu.png" width="360" alt="The HeatGlance panel open from the menu bar">

The icon is a thermometer that climbs as the Mac works harder: low, medium, high. Click it when the fans spin up or everything feels slow, and you get the numbers, the app behind them and the buttons to act. HeatGlance lives only in the menu bar, with no Dock icon and no main window.

## When you are not at the screen

Presence comes from the lock screen, display sleep, session changes and five minutes without input. A video, a call or a presentation keeps you present, for up to an hour.

When thermal pressure stays serious for sixty seconds and you are away, HeatGlance picks the apps above 50% CPU and pauses them: up to three in the first round, six in total, with a second round after two minutes. A paused app stays frozen with its state intact. Apps come back after two minutes of cooler running, one every thirty seconds, and the protection then waits ten minutes before trying again. With you present it sends a notification instead.

Two rules keep this safe. Only whole apps with a bundle identifier are paused, never bare processes, and every pause is written to disk before it happens and undone at the next launch, so a crash cannot leave an app frozen. Protection is on by default. You can pause it for an hour or until tomorrow, turn it off, or list the apps it must never touch.

## The rest of the watch

Most of what HeatGlance does never needs the panel open:

- memory that keeps growing: an app that gains 1 GB over three hours and keeps climbing gets a notification with Relaunch, Quit and Ignore;
- heavy writers: an app that writes 10 GB in an hour or 50 GB in a day gets a notification;
- unusual load: after a week of samples, a 5× CPU or 3× memory jump over an app's own baseline;
- leftover processes: helpers still running after their app is gone;
- space: files over 1 GB in watched folders, and folders that grow by several gigabytes.

A bare process, such as a script started from a shell, is reported but never paused.

## The panel

The header names the worst thing happening right now: everything looks normal, something needs attention, or under pressure. Below it, each active warning carries the number that triggered it, for example CPU at 96%, and a button when one helps.

| Metric | What it shows |
| --- | --- |
| Thermal | macOS thermal pressure and the hottest die sensor, in °C, when it can be read |
| CPU | System-wide CPU load |
| Memory | macOS memory pressure, with the biggest consumer named in the warning |
| Swap | Swap in use, which grows when memory runs short |
| Disk free | Free space in gigabytes |

Then comes the list of apps:

- the four apps using the most CPU, grouped by app, each with a menu for Suspend, Quit and Ignore for an hour;
- apps paused by the protection, with Resume and Resume all;
- leftover processes, helpers still running after their app quit.

The footer holds Sleep display, Cleanup, History, Settings and Quit.

## Warnings that hold, then clear

A warning shows up only after the condition lasts: a minute of serious thermal pressure, two minutes of CPU at 90% or more, five minutes of growing swap. It goes away when the condition does. Once a warning has produced a notification, the next one for the same condition waits fifteen minutes, so a long burst does not turn into a stream of alerts.

Default thresholds, all adjustable in Settings:

- serious thermal pressure lasting 60 seconds
- system CPU over 90% for 2 minutes
- one app over 150% CPU for 2 minutes
- swap over 25% of physical memory for 5 minutes
- less than 20 GB free on disk

## Knows the usual suspects

A bundled list explains the processes people blame most: Spotlight indexing, kernel_task, Docker, Chrome helpers, Xcode builds and others. For each one HeatGlance says what it does, whether the load is normal, and whether stopping it is wise. When the app is one of those, the row says that waiting is usually better.

## Freeing space

The Cleanup window measures a short list of known caches and empties them on request:

- Xcode DerivedData, iOS DeviceSupport and simulators whose runtime is gone;
- Homebrew downloads, the npm cache, the pnpm store and unused Docker images;
- Time Machine local snapshots, listed for reference. Deleting them needs administrator rights that HeatGlance does not ask for yet.

Only the folders in that list are touched. Sizes are measured before you clean, so you know what you are about to free.

## History

The History window has a 24 hour chart of CPU with the worst process of each minute, and a weekly report with minutes spent in serious thermal pressure, protection interventions, and the apps that used the most CPU, memory and disk writes, plus how much each one changed from the week before.

This is where you see what happened while you were away.

## Settings

- Launch at login.
- Sampling every 2 seconds, or every 5 seconds on power and 10 seconds on battery.
- Alert thresholds for thermal, CPU, swap and disk.
- Thermal protection: trigger level, sustain time, presence signals, never-pause list.
- Ignored items, the large file threshold and the weekly summary.

## What it never does

- It never acts alone. Thermal protection pauses apps and resumes them; Suspend, Quit and Ignore wait for your click.
- It uses no privileged helper, no Apple Events and no Accessibility access.
- It sends nothing anywhere. There is no network code, and every setting and history file stays on the Mac.

## Requirements

- macOS 14 or later
- Apple silicon
- Xcode 16 or later, with XcodeGen (`brew install xcodegen`)

## Build and run

```bash
./build.sh          # Debug build into build/
./run.sh            # build, then open the app
./test.sh           # package tests, then check the project generates
./release.sh        # Developer ID build, notarized DMG into dist/
```

`release.sh` reads the Apple team identifier from `HEATGLANCE_TEAM_ID` and the notary credentials from the `HEATGLANCE_NOTARY_PROFILE` keychain profile.

## Permissions

- Notifications, for the alerts. Nothing is sent anywhere.
- Full disk access, optional, to measure folders and scan files inside protected folders.
- No other permissions are requested.

## License

MIT, see `LICENSE`.
