# HRV trend and data semantics

WristGrove reads HealthKit's `heartRateVariabilitySDNN` quantity and displays milliseconds. SDNN describes a recorded sample; it is neither a continuous signal nor a direct measurement of psychological stress. WristGrove does not diagnose, produce a stress/recovery score, or trigger stress alerts.

## Source and windows

- Use Apple Watch samples only by default; exclude manually entered and non-finite/non-positive values. Preserve HealthKit UUID and stable source/device identity. Never combine different sources or HRV types in one baseline.
- Divide dates using the user's current Gregorian calendar and time zone, not fixed 86,400-second blocks. The rolling history contains the previous 28 complete local calendar days.
- Each hour, compare today's samples before that completed local hour with each historical day before the same local hour. Compute a median per day. Require at least three valid samples today and on each contributing historical day, and seven contributing historical days. Otherwise show “Accumulating”.
- Calculate the linear-interpolated Q25/Q75 of those daily medians. Below Q25 is “Below your recent range”; strictly inside the interval is “Within your recent middle range”; above Q75 is “Above your recent range”. When Q25 equals Q75, show insufficient variation rather than a grade. These thresholds describe a personal sample distribution; they are not medical cutoffs.
- Show the latest sample as its own value with its source time. A timeline refresh never changes the sample timestamp. Seven- and 28-day charts use complete local days only.
- After a time-zone change, rebuild daily grouping and baseline. Version every baseline; while a matching baseline is unavailable, show the measured value and “Accumulating”.

Steps use HealthKit statistics and do not sum potentially overlapping device totals. Sleep intervals are merged within each source; prefer a Watch source when present. Both source selection rules are documented as estimates rather than Apple's private Health source-priority behavior.

## Missing, stale and failed data

Show no data, query failure, stale cached data and insufficient history as different states. A failed query may keep a previous number visible with its actual sample time, but cannot make that number current or update a trend. HealthKit intentionally does not reveal whether read access was denied. When no sample is visible, explain that the user can check Health access or wait for Apple Watch to record a sample.

