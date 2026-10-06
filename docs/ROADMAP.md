# Roadmap

Each milestone has a release gate. A successful simulator build is not device or TestFlight validation.

| Version | Delivery | Exit criteria |
| --- | --- | --- |
| 0.1 | iOS/Watch/widget prototype, simulated provider, shared core, project docs and CI | All targets build; core tests pass; demo mode is explicit and complete. |
| 0.2 | Read-only HealthKit data, history, trend, face widgets and cached Watch sync | Paired iPhone/Watch tests cover new users, partial data, offline behavior and time-zone/day changes. |
| 0.3 | TestFlight beta, privacy policy and feedback flow | Signed beta installs on the paired devices; seven-day stability, sync and battery observations recorded. |
| 1.0 | Free App Store release | Review accepted, listed price is free, published app installs, source identifies the released commit. |

## Current status

Development has started. Public repository and signing are prerequisites for distribution. No release is complete until it has been installed and its release page/build has been checked. This repository currently targets the 0.1 gate; device and distribution checks remain separate gates.

