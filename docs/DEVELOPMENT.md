# Development and signing

The Xcode project supports iOS 17 and watchOS 10 and should be opened with Xcode 26 or newer. Full Xcode is required for Apple target compilation, simulators, signing and archiving. The shared domain package can be built and tested with Swift 6:

```sh
swift test --package-path Packages/WristGroveCore
```

Select `WristGrove` to run the iPhone app, or `WristGrove Watch` to run the paired Watch target. App Store/TestFlight signing is automatic when a valid personal Team is selected in Xcode. `Config/Local.xcconfig` is gitignored for local identity overrides; provisioning profiles, certificates, private keys and tokens must never be committed.

HealthKit reads are optional. The first-run experience can use explicit demo mode without Health access. To check simulator UI, use synthetic fixtures. HealthKit delivery, WatchConnectivity background queues, widgets and battery require paired-device checks; mark those separately in `docs/ACCEPTANCE.md`.

CI uses GitHub-hosted macOS runners with Xcode 26 or newer. It does not use release signing credentials. For a release, the maintainer selects the enrolled development Team, confirms privacy metadata and submits the beta/build through App Store Connect.

