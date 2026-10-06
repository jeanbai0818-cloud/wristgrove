# WristGrove development instructions

- Keep official functionality free, local and usable without an account.
- Preserve HealthKit sample timestamps and source identity. Never turn a failed or empty query into a health value of zero.
- Do not infer HealthKit read authorization from `authorizationStatus(for:)`.
- iPhone owns historical baselines; Watch uses versioned cached baselines and local recent samples.
- Keep demo and real storage/synchronization separate; no automatic demo fallback.
- Core domain code must not import HealthKit, SwiftUI or WatchConnectivity.
- Use synthetic data in tests and documentation. Do not log raw health values or commit credentials/signing files.
- Run meaningful core tests and Apple target builds for implementation changes. Record unverified device/signing checks explicitly.
- Use short branches and PRs. Do not call a TestFlight/App Store release complete without actual installation and distribution verification.

