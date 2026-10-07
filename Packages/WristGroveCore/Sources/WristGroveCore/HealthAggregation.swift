import Foundation

public struct StepSourceTotal: Sendable, Equatable {
    public let sourceID: String
    public let value: Double
    public let isAppleSource: Bool

    public init(sourceID: String, value: Double, isAppleSource: Bool) {
        self.sourceID = sourceID
        self.value = value
        self.isAppleSource = isAppleSource
    }
}

public struct SleepInterval: Sendable, Equatable {
    public let sourceID: String
    public let start: Date
    public let end: Date
    public let isAppleWatch: Bool

    public init(sourceID: String, start: Date, end: Date, isAppleWatch: Bool) {
        self.sourceID = sourceID
        self.start = start
        self.end = end
        self.isAppleWatch = isAppleWatch
    }
}

public struct SleepSummary: Sendable, Equatable {
    public let sourceID: String
    public let durationSeconds: TimeInterval
    public let sampledAt: Date

    public init(sourceID: String, durationSeconds: TimeInterval, sampledAt: Date) {
        self.sourceID = sourceID
        self.durationSeconds = durationSeconds
        self.sampledAt = sampledAt
    }
}

/// Conservative aggregation rules for sources that can overlap in HealthKit.
/// These rules are estimates and do not reproduce Health's private source ranking.
public enum HealthAggregation {
    /// Select one source instead of adding device totals that may overlap.
    public static func preferredSteps(from totals: [StepSourceTotal]) -> StepSourceTotal? {
        let valid = totals.filter {
            !$0.sourceID.isEmpty && $0.value.isFinite && $0.value >= 0
        }
        let apple = valid.filter(\.isAppleSource)
        return (apple.isEmpty ? valid : apple).sorted {
            if $0.value == $1.value { return $0.sourceID < $1.sourceID }
            return $0.value > $1.value
        }.first
    }

    /// Merge overlap within each source, prefer a Watch source when present,
    /// then select one source so duplicate recordings are never summed.
    public static func preferredSleepSummary(from intervals: [SleepInterval]) -> SleepSummary? {
        let valid = intervals.filter {
            !$0.sourceID.isEmpty &&
            $0.start.timeIntervalSinceReferenceDate.isFinite &&
            $0.end.timeIntervalSinceReferenceDate.isFinite &&
            $0.end > $0.start
        }
        let summaries = Dictionary(grouping: valid, by: \.sourceID).compactMap { sourceID, sourceIntervals in
            mergedSummary(sourceID: sourceID, intervals: sourceIntervals)
        }
        let watches = summaries.filter { $0.isAppleWatch }
        let preferred = watches.isEmpty ? summaries : watches
        return preferred.sorted {
            if $0.summary.durationSeconds == $1.summary.durationSeconds {
                return $0.summary.sourceID < $1.summary.sourceID
            }
            return $0.summary.durationSeconds > $1.summary.durationSeconds
        }.first?.summary
    }

    private static func mergedSummary(sourceID: String, intervals: [SleepInterval])
        -> (summary: SleepSummary, isAppleWatch: Bool)? {
        let sorted = intervals.sorted {
            if $0.start == $1.start { return $0.end < $1.end }
            return $0.start < $1.start
        }
        guard let first = sorted.first else { return nil }
        var segmentStart = first.start
        var segmentEnd = first.end
        var duration: TimeInterval = 0

        for interval in sorted.dropFirst() {
            if interval.start <= segmentEnd {
                segmentEnd = max(segmentEnd, interval.end)
            } else {
                duration += segmentEnd.timeIntervalSince(segmentStart)
                segmentStart = interval.start
                segmentEnd = interval.end
            }
        }
        duration += segmentEnd.timeIntervalSince(segmentStart)
        guard duration.isFinite, duration > 0 else { return nil }
        let latestEnd = sorted.map(\.end).max() ?? segmentEnd
        return (
            SleepSummary(sourceID: sourceID, durationSeconds: duration, sampledAt: latestEnd),
            intervals.contains(where: \.isAppleWatch)
        )
    }
}
