import Foundation
import XCTest
@testable import WristGroveCore

final class HealthAggregationTests: XCTestCase {
    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testStepsSelectOnePreferredAppleSourceWithoutSumming() {
        let selected = HealthAggregation.preferredSteps(from: [
            StepSourceTotal(sourceID: "com.apple.watch.1", value: 2_400, isAppleSource: true),
            StepSourceTotal(sourceID: "com.apple.phone", value: 1_900, isAppleSource: true),
            StepSourceTotal(sourceID: "com.example.pedometer", value: 12_000, isAppleSource: false)
        ])

        XCTAssertEqual(selected?.sourceID, "com.apple.watch.1")
        XCTAssertEqual(selected?.value, 2_400)
    }

    func testStepsFallBackToLargestValidSourceWhenNoAppleSourceExists() {
        let selected = HealthAggregation.preferredSteps(from: [
            StepSourceTotal(sourceID: "com.example.first", value: .nan, isAppleSource: false),
            StepSourceTotal(sourceID: "com.example.second", value: 3_100, isAppleSource: false),
            StepSourceTotal(sourceID: "com.example.third", value: -1, isAppleSource: false)
        ])

        XCTAssertEqual(selected?.sourceID, "com.example.second")
        XCTAssertEqual(selected?.value, 3_100)
    }

    func testZeroStepCountRemainsAValidReading() {
        let selected = HealthAggregation.preferredSteps(from: [
            StepSourceTotal(sourceID: "com.apple.watch", value: 0, isAppleSource: true)
        ])

        XCTAssertEqual(selected?.value, 0)
    }

    func testSleepMergesOverlappingWatchIntervalsAndPrefersWatchSource() {
        let selected = HealthAggregation.preferredSleepSummary(from: [
            SleepInterval(sourceID: "watch:one", start: date("2026-10-06T22:00:00Z"),
                          end: date("2026-10-06T23:00:00Z"), isAppleWatch: true),
            SleepInterval(sourceID: "watch:one", start: date("2026-10-06T22:30:00Z"),
                          end: date("2026-10-07T00:00:00Z"), isAppleWatch: true),
            SleepInterval(sourceID: "watch:one", start: date("2026-10-07T00:30:00Z"),
                          end: date("2026-10-07T01:00:00Z"), isAppleWatch: true),
            SleepInterval(sourceID: "watch:one", start: date("2026-10-06T22:30:00Z"),
                          end: date("2026-10-07T00:00:00Z"), isAppleWatch: true),
            SleepInterval(sourceID: "phone:one", start: date("2026-10-06T21:00:00Z"),
                          end: date("2026-10-07T02:00:00Z"), isAppleWatch: false)
        ])

        XCTAssertEqual(selected?.sourceID, "watch:one")
        XCTAssertEqual(selected?.durationSeconds, 2.5 * 60 * 60)
        XCTAssertEqual(selected?.sampledAt, date("2026-10-07T01:00:00Z"))
    }

    func testSleepNeverAddsSeparateSourcesAndRejectsInvalidIntervals() {
        let selected = HealthAggregation.preferredSleepSummary(from: [
            SleepInterval(sourceID: "source:b", start: date("2026-10-06T22:00:00Z"),
                          end: date("2026-10-07T01:00:00Z"), isAppleWatch: false),
            SleepInterval(sourceID: "source:a", start: date("2026-10-06T22:00:00Z"),
                          end: date("2026-10-07T01:00:00Z"), isAppleWatch: false),
            SleepInterval(sourceID: "source:invalid", start: date("2026-10-07T01:00:00Z"),
                          end: date("2026-10-07T00:00:00Z"), isAppleWatch: true)
        ])

        XCTAssertEqual(selected?.sourceID, "source:a")
        XCTAssertEqual(selected?.durationSeconds, 3 * 60 * 60)
    }
}
