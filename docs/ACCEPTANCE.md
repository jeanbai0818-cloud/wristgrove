# Acceptance checklist

## Automated

- Core package tests cover the HRV window, daily median, Q25/Q75 thresholds, equal quartiles, minimum sample/day rules, deterministic duplicate-ID cleanup, invalid/manual samples, source and algorithm-version mismatch, time-zone boundaries, step-source selection, overlapping sleep intervals, demo/real isolation and stale merge behavior.
- CI runs `swift test --package-path Packages/WristGroveCore`, builds the iOS app including the embedded Watch app/widget for iOS Simulator, and builds the standalone Watch app/widget for Watch Simulator with Xcode 26 or newer.
- Demo snapshots remain distinguishable in the app, Watch and complications; no demo value appears in real mode.

## Paired-device validation (record device/OS/build)

- First launch without Health samples; partial read authorization; late or missing SDNN; valid latest sample and timestamp; baseline accumulation then matching local-time HRV window.
- Watch offline after initial sync, app restart, delayed/old phone context, changed source, changed algorithm version and changed time zone.
- Locked-device/background query error preserves the prior timestamp and reports the error state. Relaunch and foreground refresh update the snapshot.
- Cross-midnight steps reset against the local calendar. Duplicate step sources are not added together. Overlapping sleep intervals from one source count only once.
- Widget families, timeline reloads under deferred system scheduling, taps into Watch detail, VoiceOver labels, dark mode and reduced screen size.
- Run background delivery without the debugger attached. Record observed refresh and battery behavior; no minimum refresh interval is claimed.
- TestFlight: signed build processes, installs on the paired devices and its build/privacy metadata match the source and policy.
