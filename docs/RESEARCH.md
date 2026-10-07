# Research and attribution

The product design uses public platform documentation and repository source/license inspection. No competitor code or artwork is copied.

| Reference | Verified use | License / limitation |
| --- | --- | --- |
| [StanfordSpezi/SpeziHealthKit](https://github.com/StanfordSpezi/SpeziHealthKit) | HealthKit query, incremental/background collection and deleted-object handling patterns | MIT; referenced, not a runtime dependency in v0.1. |
| [zeaiso/zwaeg](https://github.com/zeaiso/zwaeg) | WatchConnectivity and circular/rectangular/inline WidgetKit implementations | MIT; referenced, not copied into v0.1. |
| [W4rd2/whoordan HealthKit service](https://github.com/W4rd2/whoordan/blob/main/Whoordan/Core/HealthKit/HealthKitService.swift) | Sample origin and confidence modeling ideas | Apache-2.0 repository; inspected service currently contains unimplemented import paths, so it is not a HealthKit reader dependency. |
| [heisenbuggs/Soma](https://github.com/heisenbuggs/Soma) and [jinsoowhang/healthkit-exporter](https://github.com/jinsoowhang/healthkit-exporter) | Feature and workflow references | No clear repository license found during inspection; no source or assets reused. |
| [Grow - 你的健康贴心好伙伴](https://apps.apple.com/cn/app/grow-%E4%BD%A0%E7%9A%84%E5%81%A5%E5%BA%B7%E8%B4%B4%E5%BF%83%E5%A5%BD%E4%BC%99%E4%BC%B4/id1560604814?platform=watch) | Its public listing offers an Apple Watch app and describes Watch features such as HRV, recovery and watch-face displays | Product reference only; no code, artwork or branding reused. The listing supports the companion-app plus system-face-display approach. |

Apple references: [WidgetKit watch-face complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications), [sharing a complete Apple Watch face](https://developer.apple.com/documentation/clockkit/sharing-an-apple-watch-face), [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn), [WidgetKit refresh budget](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [WatchConnectivity transport](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity).

Grow's public listing and release notes point to a Watch app that supplies selectable displays for system faces. WristGrove follows that model: the iPhone app previews the data, the Watch app supplies the display, and the person places it in the watch-face editor. Apple also exposes an API to import a complete `.watchface` file, but Apple requires every included complication to come from an app with a valid App Store ID, such as an App Store or TestFlight build; a development-signed app ID is not accepted. Revisit one-tap face import only after a distributable build exists.

## Reuse process

Before adding code or artwork, pin its source commit, verify the actual license file, keep required copyright/license/NOTICE texts and check any separate font or image license. This source inspection itself grants no copying rights.
