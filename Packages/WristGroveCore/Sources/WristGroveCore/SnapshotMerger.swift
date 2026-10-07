import Foundation

public enum SnapshotMerger {
    /// Merge delayed WatchConnectivity snapshots without overwriting newer samples.
    /// Empty successful reads can clear a previous value (for example, deleted data),
    /// while query failures retain that value and mark the failure for the interface.
    public static func merge(local: HealthSnapshot?, incoming: HealthSnapshot,
                             now: Date) -> HealthSnapshot {
        guard let local else { return removingYesterdaySteps(from: incoming, now: now) }
        guard local.isDemo == incoming.isDemo else {
            let newer = incoming.generatedAt >= local.generatedAt ? incoming : local
            return removingYesterdaySteps(from: newer, now: now)
        }
        let incomingIsNewer = incoming.generatedAt >= local.generatedAt
        var merged = incomingIsNewer ? incoming : local
        merged.readings = MetricKind.allCases.compactMap { metric in
            chooseReading(local.reading(for: metric), incoming.reading(for: metric),
                          incomingIsNewer: incomingIsNewer)
        }
        if let incomingBaseline = incoming.baseline, let localBaseline = local.baseline {
            let useIncoming = incomingBaseline.computedAt >= localBaseline.computedAt
            merged.baseline = useIncoming ? incomingBaseline : localBaseline
        } else {
            merged.baseline = incoming.baseline ?? local.baseline
        }
        // A trend must correspond to its source's baseline. Never pair a trend from
        // one device source with a baseline from another during a source change.
        let candidates = [local, incoming].filter {
            $0.baseline?.sourceID == merged.baseline?.sourceID &&
            $0.timeZoneIdentifier == merged.timeZoneIdentifier
        }
        merged.trend = candidates.compactMap(\.trend).max { $0.assessedAt < $1.assessedAt }
        if merged.baseline?.timeZoneIdentifier != merged.timeZoneIdentifier {
            merged.baseline = nil
            merged.trend = nil
        }
        let hrvState = incoming.reading(for: .hrvSDNN)?.state
        if hrvState == .queryFailed || hrvState == .noData {
            merged.dailyHRV = local.dailyHRV
            merged.trend = nil
        } else if !incomingIsNewer && incoming.dailyHRV.isEmpty {
            merged.dailyHRV = local.dailyHRV
        }
        return removingYesterdaySteps(from: merged, now: now)
    }

    private static func chooseReading(_ local: MetricReading?, _ incoming: MetricReading?,
                                      incomingIsNewer: Bool) -> MetricReading? {
        guard let incoming else { return local }
        guard let local else { return incoming }
        if incoming.state == .queryFailed {
            guard incomingIsNewer else { return local }
            var preserved = local
            preserved.state = .queryFailed
            return preserved
        }
        if incoming.value == nil,
           incomingIsNewer,
           incoming.state == .noData,
           let priorValue = local.value,
           priorValue.isFinite,
           priorValue > 0 || (incoming.metric == .steps && priorValue == 0) {
            // HealthKit deliberately hides read-denial state. Preserve the last
            // known sample with its original timestamp and make its staleness
            // visible rather than erasing or relabeling it as a fresh reading.
            return MetricReading(metric: incoming.metric, value: priorValue,
                                 unit: incoming.unit, sampledAt: local.sampledAt,
                                 sourceID: local.sourceID, state: .stale)
        }
        if incoming.value == nil {
            return incomingIsNewer ? incoming : local
        }
        if local.value == nil {
            // A delayed sample cannot undo a newer deletion/no-data query.
            return incomingIsNewer ? incoming : local
        }
        guard let incomingDate = incoming.sampledAt else {
            return local.sampledAt == nil && incomingIsNewer ? incoming : local
        }
        guard let localDate = local.sampledAt else { return incoming }
        if incomingDate == localDate { return incomingIsNewer ? incoming : local }
        return incomingDate > localDate ? incoming : local
    }

    private static func removingYesterdaySteps(from snapshot: HealthSnapshot,
                                                now: Date) -> HealthSnapshot {
        var result = snapshot
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: snapshot.timeZoneIdentifier) ?? .current
        result.readings = snapshot.readings.map { reading in
            guard reading.metric == .steps else { return reading }
            guard calendar.isDate(snapshot.generatedAt, inSameDayAs: now),
                  let sampledAt = reading.sampledAt,
                  calendar.isDate(sampledAt, inSameDayAs: now) else {
                return MetricReading(metric: .steps, unit: reading.unit,
                                     sourceID: reading.sourceID, state: .stale)
            }
            return reading
        }
        return result
    }
}
