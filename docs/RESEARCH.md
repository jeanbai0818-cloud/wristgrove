# Research and attribution

The product design uses public platform documentation and repository source/license inspection. No competitor code or artwork is copied.

| Reference | Verified use | License / limitation |
| --- | --- | --- |
| [StanfordSpezi/SpeziHealthKit](https://github.com/StanfordSpezi/SpeziHealthKit) | HealthKit query, incremental/background collection and deleted-object handling patterns | MIT; referenced, not a runtime dependency in v0.1. |
| [zeaiso/zwaeg](https://github.com/zeaiso/zwaeg) | WatchConnectivity and circular/rectangular/inline WidgetKit implementations | MIT; referenced, not copied into v0.1. |
| [W4rd2/whoordan HealthKit service](https://github.com/W4rd2/whoordan/blob/main/Whoordan/Core/HealthKit/HealthKitService.swift) | Sample origin and confidence modeling ideas | Apache-2.0 repository; inspected service currently contains unimplemented import paths, so it is not a HealthKit reader dependency. |
| [heisenbuggs/Soma](https://github.com/heisenbuggs/Soma) and [jinsoowhang/healthkit-exporter](https://github.com/jinsoowhang/healthkit-exporter) | Feature and workflow references | No clear repository license found during inspection; no source or assets reused. |

Apple references: [WidgetKit complications](https://developer.apple.com/documentation/widgetkit/creating-accessory-widgets-and-watch-complications), [HealthKit authorization](https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data), [SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn), [widget refresh budget](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date), [WatchConnectivity transport](https://developer.apple.com/documentation/watchconnectivity/transferring-data-with-watch-connectivity).

## Reuse process

Before adding code or artwork, pin its source commit, verify the actual license file, keep required copyright/license/NOTICE texts and check any separate font or image license. This source inspection itself grants no copying rights.

