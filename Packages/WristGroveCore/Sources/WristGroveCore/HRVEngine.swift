import Foundation

/// Product-level personal-history comparison. This is not a clinical score.
/// SDNN values from different devices are intentionally never pooled.
public enum HRVEngine {
    public static let algorithmVersion = 1
    public static let historyDays = 28
    public static let minimumEffectiveDays = 7
    public static let minimumSamplesPerWindow = 3

    public static func makeBaseline(samples: [HRVSample], sourceID: String,
                                    now: Date, timeZone: TimeZone) -> HRVBaseline {
        let calendar = calendar(in: timeZone)
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -historyDays, to: end)!
        let history = clean(samples, sourceID: sourceID)
            .filter { $0.timestamp >= start && $0.timestamp < end }
        let grouped = Dictionary(grouping: history) { calendar.startOfDay(for: $0.timestamp) }
        let windows = (0...24).map { cutoffHour in
            let dailyMedians: [Double] = grouped.compactMap { day, values in
                let endOfWindow = cutoff(on: day, hour: cutoffHour, calendar: calendar)
                let windowValues = values.filter { $0.timestamp < endOfWindow }
                    .map(\.valueMilliseconds)
                guard windowValues.count >= minimumSamplesPerWindow else { return nil }
                return percentile(windowValues, fraction: 0.5)
            }
            let enoughDays = dailyMedians.count >= minimumEffectiveDays
            return BaselineWindow(
                cutoffHour: cutoffHour,
                lowerQuartile: enoughDays ? percentile(dailyMedians, fraction: 0.25) : nil,
                upperQuartile: enoughDays ? percentile(dailyMedians, fraction: 0.75) : nil,
                effectiveDays: dailyMedians.count
            )
        }
        return HRVBaseline(sourceID: sourceID, timeZoneIdentifier: timeZone.identifier,
                           computedAt: now, historyStart: start, historyEnd: end,
                           windows: windows, algorithmVersion: algorithmVersion)
    }

    public static func assess(samples: [HRVSample], baseline: HRVBaseline?,
                              now: Date, timeZone: TimeZone) -> TrendResult {
        let calendar = calendar(in: timeZone)
        let day = calendar.startOfDay(for: now)
        let hour = calendar.component(.hour, from: now)
        guard let baseline,
              baseline.algorithmVersion == algorithmVersion,
              baseline.timeZoneIdentifier == timeZone.identifier else {
            return TrendResult(band: .accumulating, cutoffHour: hour, assessedAt: now)
        }
        let end = cutoff(on: day, hour: hour, calendar: calendar)
        let current = clean(samples, sourceID: baseline.sourceID)
            .filter { $0.timestamp >= day && $0.timestamp < end && $0.timestamp <= now }
        let median = current.isEmpty ? nil : percentile(current.map(\.valueMilliseconds), fraction: 0.5)
        let window = baseline.windows.first { $0.cutoffHour == hour }
        var result = TrendResult(band: .accumulating, medianMilliseconds: median,
                                 sampleCount: current.count,
                                 effectiveDays: window?.effectiveDays ?? 0,
                                 cutoffHour: hour, assessedAt: now)
        guard let window, window.effectiveDays >= minimumEffectiveDays,
              let lower = window.lowerQuartile, let upper = window.upperQuartile,
              lower.isFinite, upper.isFinite, lower > 0, upper >= lower else { return result }
        guard current.count >= minimumSamplesPerWindow, let median else { return result }
        guard upper > lower else {
            result.band = .insufficientVariation
            return result
        }
        result.band = median < lower ? .lower : (median > upper ? .higher : .middle)
        return result
    }

    /// Daily history includes only complete calendar days, never today's partial window.
    public static func dailyHistory(samples: [HRVSample], sourceID: String,
                                    now: Date, timeZone: TimeZone,
                                    days: Int = historyDays) -> [DailyHRVPoint] {
        guard days > 0 else { return [] }
        let calendar = calendar(in: timeZone)
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -days, to: end)!
        let history = clean(samples, sourceID: sourceID)
            .filter { $0.timestamp >= start && $0.timestamp < end }
        let grouped = Dictionary(grouping: history) { calendar.startOfDay(for: $0.timestamp) }
        return grouped.map { day, values in
            DailyHRVPoint(day: day,
                          medianMilliseconds: percentile(values.map(\.valueMilliseconds), fraction: 0.5),
                          sampleCount: values.count)
        }.sorted { $0.day < $1.day }
    }

    public static func validSamples(_ samples: [HRVSample], sourceID: String) -> [HRVSample] {
        clean(samples, sourceID: sourceID)
    }

    private static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    /// Use wall-clock hour boundaries. Adding absolute hours is incorrect on DST days.
    private static func cutoff(on day: Date, hour: Int, calendar: Calendar) -> Date {
        if hour == 24 { return calendar.date(byAdding: .day, value: 1, to: day)! }
        if hour == 0 { return day }
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day,
                             matchingPolicy: .nextTime,
                             repeatedTimePolicy: .first,
                             direction: .forward)!
    }

    private static func clean(_ samples: [HRVSample], sourceID: String) -> [HRVSample] {
        var byID: [UUID: HRVSample] = [:]
        for sample in samples where sample.sourceID == sourceID && !sample.isUserEntered
            && sample.valueMilliseconds.isFinite && sample.valueMilliseconds > 0 {
            if let previous = byID[sample.id] {
                // Duplicate order cannot change the result, even for conflicting records.
                if sample.timestamp > previous.timestamp ||
                    (sample.timestamp == previous.timestamp && sample.valueMilliseconds < previous.valueMilliseconds) {
                    byID[sample.id] = sample
                }
            } else {
                byID[sample.id] = sample
            }
        }
        return byID.values.sorted {
            if $0.timestamp == $1.timestamp { return $0.id.uuidString < $1.id.uuidString }
            return $0.timestamp < $1.timestamp
        }
    }

    private static func percentile(_ values: [Double], fraction: Double) -> Double {
        let sorted = values.sorted()
        guard let first = sorted.first else { return .nan }
        guard sorted.count > 1 else { return first }
        let location = Double(sorted.count - 1) * fraction
        let lower = Int(location.rounded(.down))
        let upper = Int(location.rounded(.up))
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (location - Double(lower))
    }
}
