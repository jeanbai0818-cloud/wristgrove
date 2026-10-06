# Architecture

```text
iPhone HealthKit -> HealthKitDataProvider -> WristGroveCore -> local snapshot
                                                  |                 |
                                                  +-> iPhone UI     +-> WatchConnectivity
                                                                        |
Watch HealthKit -> HealthKitDataProvider -> WristGroveCore <-------------+
                                                  |
                                     per-device App Group snapshot
                                                  |
                                          Watch app + widgets
```

`Packages/WristGroveCore` owns platform-independent metric, state, baseline, merge and sample-trend rules. iOS is the single historical baseline producer. watchOS reads recent local HealthKit samples and consumes the matching phone baseline. If its baseline is absent or has a different source, time zone or algorithm version, it shows the reading and accumulating state.

HealthKit is the raw-sample source of truth. `HealthKitDataProvider` makes read-only authorization requests and normalizes samples. The Watch/phone transport sends versioned summaries/settings with `updateApplicationContext`; receipt time never replaces the HealthKit sample time. On each device, App Group JSON files give the app and widget the same atomic snapshot. App Groups do not bridge devices.

The snapshot store has one file per explicit demo/real mode. Widget timelines read that mode only and never manufacture example measurements. Store and baseline schemas are versioned. HealthKit background delivery and WidgetKit reloads are best-effort system schedules, not sampling timers.

