import Foundation

public enum MetricKind: String, Codable, CaseIterable, Sendable {
    case hrvSDNN, heartRate, restingHeartRate, steps, sleep
}

/// An empty HealthKit read does not reveal whether access was denied.
public enum DataState: String, Codable, Sendable {
    case available, noData, queryFailed, insufficientHistory, stale
}

public struct MetricReading: Codable, Sendable, Equatable {
    public var metric: MetricKind
    public var value: Double?
    public var unit: String
    public var sampledAt: Date?
    public var sourceID: String?
    public var state: DataState

    public init(metric: MetricKind, value: Double? = nil, unit: String,
                sampledAt: Date? = nil, sourceID: String? = nil,
                state: DataState = .available) {
        self.metric = metric
        self.value = value
        self.unit = unit
        self.sampledAt = sampledAt
        self.sourceID = sourceID
        self.state = state
    }
}

public struct HRVSample: Codable, Sendable, Equatable {
    public var id: UUID
    public var valueMilliseconds: Double
    public var timestamp: Date
    public var sourceID: String
    public var isUserEntered: Bool

    public init(id: UUID, valueMilliseconds: Double, timestamp: Date,
                sourceID: String, isUserEntered: Bool = false) {
        self.id = id
        self.valueMilliseconds = valueMilliseconds
        self.timestamp = timestamp
        self.sourceID = sourceID
        self.isUserEntered = isUserEntered
    }
}

public struct DailyHRVPoint: Codable, Sendable, Equatable {
    public var day: Date
    public var medianMilliseconds: Double
    public var sampleCount: Int

    public init(day: Date, medianMilliseconds: Double, sampleCount: Int) {
        self.day = day
        self.medianMilliseconds = medianMilliseconds
        self.sampleCount = sampleCount
    }
}

public enum HRVBand: String, Codable, Sendable {
    case lower, middle, higher, accumulating, insufficientVariation
}

public struct BaselineWindow: Codable, Sendable, Equatable {
    public var cutoffHour: Int
    public var lowerQuartile: Double?
    public var upperQuartile: Double?
    public var effectiveDays: Int

    public init(cutoffHour: Int, lowerQuartile: Double? = nil,
                upperQuartile: Double? = nil, effectiveDays: Int = 0) {
        self.cutoffHour = cutoffHour
        self.lowerQuartile = lowerQuartile
        self.upperQuartile = upperQuartile
        self.effectiveDays = effectiveDays
    }
}

public struct HRVBaseline: Codable, Sendable, Equatable {
    public var sourceID: String
    public var timeZoneIdentifier: String
    public var computedAt: Date
    public var historyStart: Date
    public var historyEnd: Date
    public var windows: [BaselineWindow]
    public var algorithmVersion: Int

    public init(sourceID: String, timeZoneIdentifier: String, computedAt: Date,
                historyStart: Date, historyEnd: Date, windows: [BaselineWindow],
                algorithmVersion: Int = 1) {
        self.sourceID = sourceID
        self.timeZoneIdentifier = timeZoneIdentifier
        self.computedAt = computedAt
        self.historyStart = historyStart
        self.historyEnd = historyEnd
        self.windows = windows
        self.algorithmVersion = algorithmVersion
    }
}

public struct TrendResult: Codable, Sendable, Equatable {
    public var band: HRVBand
    public var medianMilliseconds: Double?
    public var sampleCount: Int
    public var effectiveDays: Int
    public var cutoffHour: Int
    public var assessedAt: Date

    public init(band: HRVBand, medianMilliseconds: Double? = nil,
                sampleCount: Int = 0, effectiveDays: Int = 0,
                cutoffHour: Int, assessedAt: Date) {
        self.band = band
        self.medianMilliseconds = medianMilliseconds
        self.sampleCount = sampleCount
        self.effectiveDays = effectiveDays
        self.cutoffHour = cutoffHour
        self.assessedAt = assessedAt
    }
}

public struct HealthSnapshot: Codable, Sendable, Equatable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var timeZoneIdentifier: String
    public var isDemo: Bool
    public var readings: [MetricReading]
    public var baseline: HRVBaseline?
    public var trend: TrendResult?
    public var dailyHRV: [DailyHRVPoint]

    public init(schemaVersion: Int = 1, generatedAt: Date,
                timeZoneIdentifier: String = TimeZone.current.identifier,
                isDemo: Bool = false, readings: [MetricReading] = [],
                baseline: HRVBaseline? = nil, trend: TrendResult? = nil,
                dailyHRV: [DailyHRVPoint] = []) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.isDemo = isDemo
        self.readings = readings
        self.baseline = baseline
        self.trend = trend
        self.dailyHRV = dailyHRV
    }

    public func reading(for metric: MetricKind) -> MetricReading? {
        readings.first { $0.metric == metric }
    }
}

public protocol HealthDataProvider: Sendable {
    func requestAuthorization() async throws
    func fetchSnapshot(at date: Date, baseline: HRVBaseline?) async throws -> HealthSnapshot
}
