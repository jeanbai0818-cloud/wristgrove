# Roadmap

Each milestone has a release gate. A successful simulator build is not device or TestFlight validation.

| Version | Delivery | Exit criteria |
| --- | --- | --- |
| 0.1 | iOS/Watch/widget prototype, simulated provider, shared core, project docs and CI | All targets build; core tests pass; demo mode is explicit and complete. |
| 0.2 | Read-only HealthKit data, history, trend, face widgets and cached Watch sync | Paired iPhone/Watch tests cover new users, partial data, offline behavior and time-zone/day changes. |
| 0.3 | TestFlight beta, privacy policy and feedback flow | Signed beta installs on the paired devices; seven-day stability, sync and battery observations recorded. |
| 1.0 | Free App Store release | Review accepted, listed price is free, published app installs, source identifies the released commit. |

## Current status

The v0.1 prototype code gate passed on 2026-10-07: the shared core tests and iOS/watchOS Simulator builds passed in GitHub Actions. The v0.2 HealthKit, baseline, widget and cached-sync implementation is present; paired-device validation remains pending. Its release gate remains open until the paired-device checklist records real-data, offline, cross-day, permission and background-delivery results.

Distribution and signing remain later gates. No release is complete until it has been installed and its release page/build has been checked.
