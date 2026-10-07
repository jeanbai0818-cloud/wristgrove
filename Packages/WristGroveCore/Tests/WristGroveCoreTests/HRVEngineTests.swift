import Foundation
import XCTest
@testable import WristGroveCore

final class HRVEngineTests: XCTestCase {
    private let utc = TimeZone(secondsFromGMT: 0)!

    private func day(_ offset: Int, from now: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = utc
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: offset, to: today)!
    }

    private func sample(_ value: Double, dayOffset: Int, hour: Int,
                        index: Int, now: Date, source: String = "watch:A") -> HRVSample {
        let date = day(dayOffset, from: now).addingTimeInterval(TimeInterval(hour * 3600))
        return HRVSample(
            id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012x", index + 1))!,
            valueMilliseconds: value,
            timestamp: date,
            sourceID: source
        )
    }

    private func historicalSamples(now: Date, values: [Double] = Array(10...17).map(Double.init)) -> [HRVSample] {
        values.enumerated().flatMap { dayIndex, value in
            [5, 6, 7].enumerated().map { index, hour in
                sample(value, dayOffset: dayIndex - values.count, hour: hour,
                       index: dayIndex * 3 + index, now: now)
            }
        }
    }

    func testMatchingHourAndQuartiles() {
        let now = Date(timeIntervalSince1970: 1_791_281_400) // 2026-10-06 10:10 UTC
        let samples = historicalSamples(now: now)
        let baseline = HRVEngine.makeBaseline(samples: samples, sourceID: "watch:A", now: now, timeZone: utc)
        let window = baseline.windows.first { $0.cutoffHour == 10 }

        XCTAssertTrue(window?.effectiveDays == 8)
        XCTAssertTrue(window?.lowerQuartile == 11.75)
        XCTAssertTrue(window?.upperQuartile == 15.25)

        let today = [sample(11, dayOffset: 0, hour: 5, index: 100, now: now),
                     sample(11, dayOffset: 0, hour: 6, index: 101, now: now),
                     sample(11, dayOffset: 0, hour: 9, index: 102, now: now)]
        let result = HRVEngine.assess(samples: samples + today, baseline: baseline, now: now, timeZone: utc)
        XCTAssertTrue(result.cutoffHour == 10)
        XCTAssertTrue(result.sampleCount == 3)
        XCTAssertTrue(result.band == .lower)
        XCTAssertTrue(result.medianMilliseconds == 11)
    }

    func testQuartileBoundaries() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let history = historicalSamples(now: now)
        let baseline = HRVEngine.makeBaseline(samples: history, sourceID: "watch:A", now: now, timeZone: utc)

        func band(_ value: Double) -> HRVBand {
            let today = [5, 6, 9].enumerated().map { index, hour in
                sample(value, dayOffset: 0, hour: hour, index: 200 + index, now: now)
            }
            return HRVEngine.assess(samples: history + today, baseline: baseline, now: now, timeZone: utc).band
        }

        XCTAssertTrue(band(11.75) == .middle)
        XCTAssertTrue(band(13) == .middle)
        XCTAssertTrue(band(15.25) == .middle)
        XCTAssertTrue(band(11.5) == .lower)
        XCTAssertTrue(band(15.5) == .higher)
    }

    func testMinimumData() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let tooFewDays = historicalSamples(now: now, values: [10, 11, 12, 13, 14, 15])
        let baseline = HRVEngine.makeBaseline(samples: tooFewDays, sourceID: "watch:A", now: now, timeZone: utc)
        let today = [sample(20, dayOffset: 0, hour: 5, index: 300, now: now),
                     sample(21, dayOffset: 0, hour: 6, index: 301, now: now),
                     sample(22, dayOffset: 0, hour: 9, index: 302, now: now)]
        XCTAssertTrue(HRVEngine.assess(samples: tooFewDays + today, baseline: baseline, now: now, timeZone: utc).band == .accumulating)

        let enoughHistory = historicalSamples(now: now)
        let enoughBaseline = HRVEngine.makeBaseline(samples: enoughHistory, sourceID: "watch:A", now: now, timeZone: utc)
        XCTAssertTrue(HRVEngine.assess(samples: enoughHistory + Array(today.prefix(2)), baseline: enoughBaseline, now: now, timeZone: utc).band == .accumulating)
    }

    func testUnsupportedBaselineAlgorithmAccumulates() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let history = historicalSamples(now: now)
        var baseline = HRVEngine.makeBaseline(samples: history, sourceID: "watch:A", now: now, timeZone: utc)
        baseline.algorithmVersion += 1
        let today = [sample(20, dayOffset: 0, hour: 5, index: 350, now: now),
                     sample(21, dayOffset: 0, hour: 6, index: 351, now: now),
                     sample(22, dayOffset: 0, hour: 9, index: 352, now: now)]

        let result = HRVEngine.assess(samples: history + today, baseline: baseline, now: now, timeZone: utc)

        XCTAssertEqual(result.band, .accumulating)
        XCTAssertEqual(result.sampleCount, 0)
    }

    func testSamplesFromAnotherSourceDoNotMatchBaseline() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let sourceAHistory = historicalSamples(now: now)
        let baseline = HRVEngine.makeBaseline(samples: sourceAHistory, sourceID: "watch:B", now: now, timeZone: utc)
        let sourceAToday = [sample(20, dayOffset: 0, hour: 5, index: 360, now: now),
                            sample(21, dayOffset: 0, hour: 6, index: 361, now: now),
                            sample(22, dayOffset: 0, hour: 9, index: 362, now: now)]

        let result = HRVEngine.assess(samples: sourceAHistory + sourceAToday, baseline: baseline, now: now, timeZone: utc)

        XCTAssertEqual(result.band, .accumulating)
        XCTAssertEqual(result.sampleCount, 0)
    }

    func testInsufficientVariation() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let history = historicalSamples(now: now, values: Array(repeating: 40, count: 8))
        let baseline = HRVEngine.makeBaseline(samples: history, sourceID: "watch:A", now: now, timeZone: utc)
        let today = [sample(40, dayOffset: 0, hour: 5, index: 401, now: now),
                     sample(42, dayOffset: 0, hour: 6, index: 402, now: now),
                     sample(44, dayOffset: 0, hour: 9, index: 403, now: now)]
        XCTAssertTrue(HRVEngine.assess(samples: history + today, baseline: baseline, now: now, timeZone: utc).band == .insufficientVariation)
    }

    func testSampleCleaning() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let valid = sample(50, dayOffset: -1, hour: 5, index: 500, now: now)
        let manual = HRVSample(id: UUID(), valueMilliseconds: 50, timestamp: valid.timestamp, sourceID: "watch:A", isUserEntered: true)
        let wrongSource = sample(50, dayOffset: -1, hour: 5, index: 501, now: now, source: "watch:B")
        let invalid = HRVSample(id: UUID(), valueMilliseconds: .infinity, timestamp: valid.timestamp, sourceID: "watch:A")

        let result = HRVEngine.validSamples([valid, valid, manual, wrongSource, invalid], sourceID: "watch:A")
        XCTAssertTrue(result == [valid])

        let conflictingDuplicate = HRVSample(id: valid.id, valueMilliseconds: 49,
                                             timestamp: valid.timestamp, sourceID: "watch:A")
        let forward = HRVEngine.validSamples([valid, conflictingDuplicate], sourceID: "watch:A")
        let reversed = HRVEngine.validSamples([conflictingDuplicate, valid], sourceID: "watch:A")
        XCTAssertEqual(forward, reversed)
        XCTAssertEqual(forward.first?.valueMilliseconds, 49)
    }

    func testTimezoneChange() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let history = historicalSamples(now: now)
        let baseline = HRVEngine.makeBaseline(samples: history, sourceID: "watch:A", now: now, timeZone: utc)
        let changedZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertTrue(HRVEngine.assess(samples: history, baseline: baseline, now: now, timeZone: changedZone).band == .accumulating)
    }

    func testCalendarDayBoundaries() {
        let zone = TimeZone(identifier: "America/Los_Angeles")!
        let now = ISO8601DateFormatter().date(from: "2026-03-08T12:00:00Z")!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
        var history: [HRVSample] = []
        for index in 0..<3 {
            let sampleTime = yesterday.addingTimeInterval(TimeInterval(index + 1) * 3_600)
            history.append(HRVSample(id: UUID(), valueMilliseconds: Double(40 + index),
                                     timestamp: sampleTime, sourceID: "watch:A"))
        }
        let points = HRVEngine.dailyHistory(samples: history, sourceID: "watch:A", now: now, timeZone: zone, days: 2)
        XCTAssertTrue(points.count == 1)
        XCTAssertTrue(calendar.isDate(points[0].day, inSameDayAs: yesterday))
        XCTAssertTrue(points[0].sampleCount == 3)
        XCTAssertEqual(points[0].medianMilliseconds, 41)
    }
}

final class SnapshotMergerTests: XCTestCase {
    func testPreservesOnFailure() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let sampledAt = now.addingTimeInterval(-120)
        let local = HealthSnapshot(generatedAt: now.addingTimeInterval(-180), isDemo: false,
                                   readings: [MetricReading(metric: .hrvSDNN, value: 48, unit: "ms", sampledAt: sampledAt)])
        let incoming = HealthSnapshot(generatedAt: now, isDemo: false,
                                      readings: [MetricReading(metric: .hrvSDNN, unit: "ms", state: .queryFailed)])
        let merged = SnapshotMerger.merge(local: local, incoming: incoming, now: now)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.value == 48)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.sampledAt == sampledAt)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.state == .queryFailed)
        XCTAssertTrue(merged.trend == nil)
    }

    func testRetainsLastSampleWithOriginalTimestampWhenHealthKitReturnsNoData() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let sampledAt = now.addingTimeInterval(-600)
        let local = HealthSnapshot(generatedAt: now.addingTimeInterval(-900), isDemo: false,
                                   readings: [MetricReading(metric: .hrvSDNN, value: 52, unit: "ms", sampledAt: sampledAt)])
        let incoming = HealthSnapshot(generatedAt: now, isDemo: false,
                                      readings: [MetricReading(metric: .hrvSDNN, unit: "ms", state: .noData)])
        let merged = SnapshotMerger.merge(local: local, incoming: incoming, now: now)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.value == 52)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.sampledAt == sampledAt)
        XCTAssertTrue(merged.reading(for: .hrvSDNN)?.state == .stale)
        XCTAssertTrue(merged.trend == nil)
    }

    func testZeroStepCountIsPreservedAsAStaleValue() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let sampledAt = now.addingTimeInterval(-60)
        let local = HealthSnapshot(generatedAt: now.addingTimeInterval(-120), isDemo: false,
                                   readings: [MetricReading(metric: .steps, value: 0, unit: "steps", sampledAt: sampledAt)])
        let incoming = HealthSnapshot(generatedAt: now, isDemo: false,
                                      readings: [MetricReading(metric: .steps, unit: "steps", state: .noData)])
        let merged = SnapshotMerger.merge(local: local, incoming: incoming, now: now)
        XCTAssertTrue(merged.reading(for: .steps)?.value == 0)
        XCTAssertTrue(merged.reading(for: .steps)?.state == .stale)
    }

    func testSeparatesModes() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let real = HealthSnapshot(generatedAt: now, isDemo: false,
                                  readings: [MetricReading(metric: .steps, value: 200, unit: "steps")])
        let demo = HealthSnapshot(generatedAt: now.addingTimeInterval(1), isDemo: true,
                                  readings: [MetricReading(metric: .hrvSDNN, value: 50, unit: "ms")])
        let merged = SnapshotMerger.merge(local: real, incoming: demo, now: now)
        XCTAssertTrue(merged.isDemo)
        XCTAssertTrue(merged.readings.map(\.metric) == [.hrvSDNN])
    }

    func testExpiresPreviousDaySteps() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let yesterday = now.addingTimeInterval(-86_400)
        let snapshot = HealthSnapshot(generatedAt: yesterday, isDemo: false,
                                      readings: [MetricReading(metric: .steps, value: 8_000, unit: "steps", sampledAt: yesterday)])
        let merged = SnapshotMerger.merge(local: nil, incoming: snapshot, now: now)
        XCTAssertTrue(merged.reading(for: .steps)?.value == nil)
        XCTAssertTrue(merged.reading(for: .steps)?.state == .stale)
    }

    func testOlderSampleDoesNotOverwriteNewerValueWhenSnapshotArrivesLater() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let recentSample = now.addingTimeInterval(-60)
        let olderSample = now.addingTimeInterval(-3_600)
        let local = HealthSnapshot(generatedAt: now.addingTimeInterval(-120), isDemo: false,
                                   readings: [MetricReading(metric: .hrvSDNN, value: 55, unit: "ms", sampledAt: recentSample)])
        let incoming = HealthSnapshot(generatedAt: now, isDemo: false,
                                      readings: [MetricReading(metric: .hrvSDNN, value: 42, unit: "ms", sampledAt: olderSample)])

        let merged = SnapshotMerger.merge(local: local, incoming: incoming, now: now)

        XCTAssertEqual(merged.reading(for: .hrvSDNN)?.value, 55)
        XCTAssertEqual(merged.reading(for: .hrvSDNN)?.sampledAt, recentSample)
    }

    func testNewerSampleWinsEvenWhenSnapshotWasGeneratedEarlier() {
        let now = Date(timeIntervalSince1970: 1_791_281_400)
        let localSample = now.addingTimeInterval(-3_600)
        let incomingSample = now.addingTimeInterval(-60)
        let local = HealthSnapshot(generatedAt: now, isDemo: false,
                                   readings: [MetricReading(metric: .hrvSDNN, value: 45, unit: "ms", sampledAt: localSample)])
        let delayed = HealthSnapshot(generatedAt: now.addingTimeInterval(-300), isDemo: false,
                                     readings: [MetricReading(metric: .hrvSDNN, value: 57, unit: "ms", sampledAt: incomingSample)])

        let merged = SnapshotMerger.merge(local: local, incoming: delayed, now: now)

        XCTAssertEqual(merged.reading(for: .hrvSDNN)?.value, 57)
        XCTAssertEqual(merged.reading(for: .hrvSDNN)?.sampledAt, incomingSample)
    }
}
