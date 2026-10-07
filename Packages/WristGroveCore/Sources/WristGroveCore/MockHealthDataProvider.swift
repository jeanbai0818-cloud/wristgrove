import Foundation

/// Deliberately synthetic data. The same date and time zone produce the same snapshot.
/// No account, authorization, network access, or HealthKit writes are involved.
public struct MockHealthDataProvider: HealthDataProvider {
    public let timeZone: TimeZone
    public let sourceID: String

    public init(timeZone: TimeZone = .current, sourceID: String = "demo.apple-watch") {
        self.timeZone = timeZone
        self.sourceID = sourceID
    }

    public func requestAuthorization() async throws {}

    public func fetchSnapshot(at date: Date, baseline: HRVBaseline? = nil) async throws -> HealthSnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let samples = samples(at: date)
        let selectedBaseline: HRVBaseline
        if let baseline, baseline.sourceID == sourceID,
           baseline.timeZoneIdentifier == timeZone.identifier,
           calendar.isDate(baseline.historyEnd, inSameDayAs: date) {
            selectedBaseline = baseline
        } else {
            selectedBaseline = HRVEngine.makeBaseline(samples: samples, sourceID: sourceID,
                                                       now: date, timeZone: timeZone)
        }
        let latest = samples.max { $0.timestamp < $1.timestamp }
        let start = calendar.startOfDay(for: date)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: start)!
        let fraction = min(1, max(0, date.timeIntervalSince(start) / nextDay.timeIntervalSince(start)))
        let phase = Double(calendar.ordinality(of: .day, in: .era, for: date) ?? 0)
        let wakeToday = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: start)!
        let wake = wakeToday <= date ? wakeToday : calendar.date(byAdding: .day, value: -1, to: wakeToday)!
        let readings: [MetricReading] = [
            MetricReading(metric: .hrvSDNN, value: latest?.valueMilliseconds, unit: "ms",
                          sampledAt: latest?.timestamp, sourceID: sourceID,
                          state: latest == nil ? .noData : .available),
            MetricReading(metric: .heartRate, value: (67 + sin(phase) * 5).rounded(), unit: "bpm",
                          sampledAt: date.addingTimeInterval(-60), sourceID: sourceID),
            MetricReading(metric: .restingHeartRate, value: (58 + cos(phase / 3) * 3).rounded(), unit: "bpm",
                          sampledAt: date.addingTimeInterval(-300), sourceID: sourceID),
            MetricReading(metric: .steps, value: (8_600 * fraction).rounded(.down), unit: "count",
                          sampledAt: date, sourceID: sourceID),
            MetricReading(metric: .sleep, value: 7.4 + sin(phase / 2) * 0.6, unit: "h",
                          sampledAt: wake, sourceID: sourceID)
        ]
        return HealthSnapshot(generatedAt: date, timeZoneIdentifier: timeZone.identifier,
                              isDemo: true, readings: readings, baseline: selectedBaseline,
                              trend: HRVEngine.assess(samples: samples, baseline: selectedBaseline,
                                                      now: date, timeZone: timeZone),
                              dailyHRV: HRVEngine.dailyHistory(samples: samples, sourceID: sourceID,
                                                              now: date, timeZone: timeZone))
    }

    public func samples(at date: Date) -> [HRVSample] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: date)
        let times = [(0, 20), (0, 50), (1, 20), (3, 20), (6, 20),
                     (9, 20), (12, 20), (15, 20), (18, 20), (21, 20)]
        return (-HRVEngine.historyDays...0).flatMap { offset -> [HRVSample] in
            let day = calendar.date(byAdding: .day, value: offset, to: today)!
            let ordinal = calendar.ordinality(of: .day, in: .era, for: day) ?? 0
            return times.enumerated().compactMap { index, time in
                guard let timestamp = calendar.date(bySettingHour: time.0, minute: time.1,
                                                     second: 0, of: day), timestamp <= date else { return nil }
                let id = UUID(uuidString: String(format: "%08x-0000-4000-8000-%012llx",
                                                 UInt32(truncatingIfNeeded: ordinal), UInt64(index)))!
                let value = 46 + sin(Double(ordinal) / 3.2) * 9 + cos(Double(index)) * 2.8
                return HRVSample(id: id, valueMilliseconds: value, timestamp: timestamp, sourceID: sourceID)
            }
        }
    }
}
