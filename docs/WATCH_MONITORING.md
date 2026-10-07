# Apple Watch dynamic monitoring design

## Product promise

WristGrove keeps the Watch view responsive to new measurements, shows exactly when each value was sampled, and compares HRV with the user's own history. It does not promise a sensor reading every two minutes, diagnose stress, or treat one outlier as a health event.

HealthKit is the public interface for the Watch's health samples; it is not the Health app's screen. The Watch and watchOS control when sensors collect and publish HRV. An observer query can react to a sample after HealthKit stores it, but it cannot command the sensor to create a new HRV sample.

## Sampling and compatibility

- Existing devices provide HealthKit SDNN (`heartRateVariabilitySDNN`). Its collection cadence varies with model, wear, activity, sleep, and system settings. Apple's 2024 technical overview describes a four-hour default cadence for its tachogram algorithm, with other cadences when certain heart features are enabled.
- Apple Watch Series 12 and Ultra 4 can record Recovery HRV as often as every five minutes while the wearer is still. Apple says the number of readings varies with activity. The watchOS 27 SDK also exposes `heartRateVariabilityRMSSD`; it is a distinct HealthKit quantity type and is never combined with SDNN samples or baselines.
- WristGrove's current implementation reads SDNN only. It must verify on an actual watch which type and cadence are available before choosing a device-specific default. A type's presence in the SDK does not prove that a particular watch publishes samples for it.
- HealthKit's `.immediate` observer frequency means the system may launch the app when matching data changes. It is a delivery preference, not a two-minute sensor timer or a real-time guarantee. WidgetKit also controls complication refresh timing.

## Target Watch experience

The current prototype still uses a trend card followed by metric tiles. The first implementation step adds a relative age to the HRV tile and reacts to new HRV samples while the app is active. The layout below is the target for the next Watch UI pass.

The main Watch screen prioritizes one current card: the latest HRV value, its method (SDNN or RMSSD), the actual sample time, and its relationship to the matching personal baseline. A short age label remains visible so users can distinguish a new sample from an older one without interpreting a stale number as live.

Use these states in the same visual location:

| State | Display |
| --- | --- |
| No sample | “等待 Apple Watch 采样” and a permission/wear hint; never show zero |
| Building history | The latest measured value plus “正在建立个人范围” |
| In personal range | A calm in-range label and sample age |
| Outside personal range | “偏离近期范围，等待后续样本” and sample age; do not call it a diagnosis or a stress measurement |
| Stale cache | Retain the value and original timestamp, visibly mark it as old |
| Query failure | Retain the last successful sample and show that refresh failed |

The complication stays compact: value or short state, with a tap target into the Watch app for method, personal range, and timestamp. It is a glance surface, not the monitoring engine; watchOS decides when it refreshes.

## Adaptive response

1. Start an `HKObserverQuery` for supported HRV sample types on Watch. When a new sample is stored while the app is active, re-query the affected window, preserve its UUID, source, method, and timestamp, and recompute the displayed state. Background delivery on Watch remains gated on entitlement and real-device verification; never implement a repeating two-minute poll.
2. Keep a separate 28-day baseline for each HRV method and source. Do not move a user from SDNN to RMSSD by mixing values. When a new method becomes available, make the method change explicit and build its history before grading it.
3. Treat one out-of-range sample as a prompt to keep observing. Change to “持续偏离” only after a second independent, valid sample also falls outside the same personal range. The state changes again only when later samples arrive; there is no claim that a recheck was forced.
4. If optional haptics are added, trigger them only on a state transition, at most once per episode, and respect the user's sleep and notification settings. Do not issue repeated two-minute alerts while waiting for the system's next sample.

## User-triggered check and sleep

The existing one-minute breathing guide is a calming exercise, not a sensor command; it currently records no HealthKit sample. Keep those meanings separate. A future “check now” flow may guide the user to sit still, show a clear one-minute progress state, and query HealthKit again afterward. It must say “no new HRV sample” if no new sample arrived. Do not label the flow an HRV measurement until a supported public API is verified on a real Watch.

During sleep, suppress optional prompts and keep collecting only samples published by watchOS. Use the sleep schedule or recorded sleep interval to provide a quiet overnight view and a morning summary. Do not promise a denser sampling rate at night; Apple changes sensor behavior during sleep and retains control of cadence.

## Delivery plan

1. Extend the domain model to carry the HRV method, version each method's baseline, and retain sample freshness independently from query status.
2. Add event-driven HealthKit observation on Watch while the app is active. Refresh the local snapshot and request a WidgetKit timeline reload after a new sample. Add background delivery only after its entitlement and Watch behavior are verified.
3. Add conditional RMSSD reading for watchOS 27 and matching iOS, without removing SDNN support for older devices. Keep the iPhone as the only historical-baseline producer.
4. Add repeated-sample confirmation and opt-in, cooldown-limited daytime haptics only after product behavior is tested. No “high stress” or medical alarms.
5. Validate on the owner's actual Watch: model and OS, sample methods and timestamps at rest/activity/sleep, no-wear/low-power behavior, offline sync, complication freshness, and battery over several days. Do not report the two-minute behavior as implemented or available.

## Platform references

- [Apple Support: Monitor your heart rate with Apple Watch](https://support.apple.com/en-us/120277) — Recovery HRV on Series 12 and Ultra 4 is sampled while still; reading count varies with activity.
- [Apple Newsroom: Apple Watch Series 12](https://www.apple.com/newsroom/2026/09/introducing-apple-watch-series-12-with-the-all-new-health-sensing-system/) — higher-frequency HRV, as often as every five minutes.
- [HealthKit `heartRateVariabilityRMSSD`](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilityrmssd) and [HealthKit SDNN](https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartratevariabilitysdnn) — separate measurement types.
- [Executing HealthKit observer queries](https://developer.apple.com/documentation/healthkit/executing-observer-queries) and [HKUpdateFrequency](https://developer.apple.com/documentation/healthkit/hkupdatefrequency) — background delivery notifies an app about HealthKit changes; it does not set sensor cadence.
- [Keeping a WidgetKit widget up to date](https://developer.apple.com/documentation/widgetkit/keeping-a-widget-up-to-date) — the system manages widget refresh budgets.
- [Apple technical overview: measuring heart rate, calorimetry, and activity](https://www.apple.com/health/pdf/Heart_Rate_Calorimetry_Activity_on_Apple_Watch_November2024.pdf) — tachogram cadence and sample context.
