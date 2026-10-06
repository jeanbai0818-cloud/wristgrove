# WristGrove · 腕森

A free, open-source Apple Watch health companion. Your health data stays on your devices.

**WristGrove is in development. It has not been released on TestFlight or the App Store.** Device validation and distribution signing are tracked separately from automated builds.

## What we are building

- iPhone: today's HRV (SDNN), heart rate, resting heart rate, sleep and steps, with 7/28-day trends.
- Apple Watch: glanceable health readings, personal HRV comparisons and a one-minute breathing guide.
- Watch face complications and Smart Stack widgets: personal HRV trend, latest HRV and steps.
- Original forest-inspired design, Chinese and English, dark mode and accessibility.
- No subscriptions, ads, accounts, backend, analytics or cloud health processing.

HRV comparisons describe your own recorded history. They are not diagnoses, psychological stress measurements or recovery scores. Sampling and background refresh are controlled by Apple. Every reading shows its original time; refreshing the app does not trigger a new HRV measurement.

## Development

Targets: iOS 17+, watchOS 10+, Swift 6. The shared package can be tested with a Swift 6 toolchain:

```sh
swift test --package-path Packages/WristGroveCore
```

Apple apps require full Xcode. Open `WristGrove.xcodeproj`, select the iPhone or Watch scheme, and run on a simulator. See [development and signing](docs/DEVELOPMENT.md). Demo mode is explicit and uses separate storage from real health data.

## Project documents

- [中文介绍](README.zh-CN.md)
- [Roadmap and release gates](docs/ROADMAP.md)
- [Algorithm and data semantics](docs/ALGORITHM.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Privacy policy](docs/PRIVACY.md)
- [Device acceptance checklist](docs/ACCEPTANCE.md)
- [Research and attribution](docs/RESEARCH.md)
- [Contributing](CONTRIBUTING.md)

## License

Apache-2.0. The official application will remain free. The license also permits third-party commercial use. Original branding and illustrations are created for this project; any future third-party code or assets must retain their own license and attribution.

