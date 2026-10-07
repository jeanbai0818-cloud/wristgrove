# Roadmap

Each milestone has a release gate. A successful simulator build is not device or TestFlight validation.

| Version | Delivery | Exit criteria |
| --- | --- | --- |
| 0.1 | Face-first iPhone setup studio, complication preview/selection and guided manual placement, Watch/widget prototype, simulated provider, shared core, docs and CI | All targets build; core tests pass; demo mode is explicit; users can choose a complication and see the matching setup steps. |
| 0.2 | Read-only HealthKit data, history, trend, face widgets, cached Watch sync and event-driven HRV updates | Paired-device tests record the actual Watch model, OS, available HRV method/cadence, sample freshness, offline behavior, sleep behavior, time-zone/day changes and battery impact. The app reacts to published samples; it does not promise two-minute sensor acquisition. |
| 0.3 | TestFlight beta, privacy policy and feedback flow | Signed beta installs on the paired devices; seven-day stability, sync and battery observations recorded. |
| 1.0 | Free App Store release | Review accepted, listed price is free, published app installs, source identifies the released commit. |

## Current status

The v0.1 prototype code gate passed on 2026-10-07: the shared core tests and iOS/watchOS Simulator builds passed in GitHub Actions. The v0.2 HealthKit, SDNN baseline, widget and cached-sync implementation is present. The Watch app now listens for new HealthKit samples while active and shows the actual HRV sample age; background Watch delivery, RMSSD support, and paired-device validation remain pending. Its release gate remains open until the paired-device checklist records real-data cadence, offline, cross-day, permission, sleep, and background-delivery results.

Distribution and signing remain later gates. No release is complete until it has been installed and its release page/build has been checked.

Apple controls watch-face editing. WristGrove can provide and preview WidgetKit complications, but the user confirms the chosen complication and its position in watchOS.
