import Foundation
@preconcurrency import HealthKit
import WristGroveCore

/// All measurements remain on the user's devices. HealthKit calls are thread
/// safe; the only mutable state (observer queries) is protected by a lock.
final class HealthKitDataProvider: HealthDataProvider, @unchecked Sendable {
    private let healthStore = HKHealthStore()
    private let observerLock = NSLock()
    private var observerQueries: [HKObserverQuery] = []

    private var quantityTypes: [HKQuantityType] {
        [.heartRateVariabilitySDNN, .heartRate, .restingHeartRate, .stepCount]
            .compactMap(HKObjectType.quantityType(forIdentifier:))
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthProviderError.unavailable }
        var readTypes = Set<HKObjectType>(quantityTypes)
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { readTypes.insert(sleep) }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
        // Success acknowledges the request, not permission to read every type.
        // HealthKit deliberately does not reveal individual read denials.
    }

    func fetchSnapshot(at now: Date, baseline: HRVBaseline?) async throws -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else { throw HealthProviderError.unavailable }
        let timeZone = TimeZone.current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let today = calendar.startOfDay(for: now)
        let queryCalendar = calendar
        #if os(iOS)
        let historyStart = calendar.date(byAdding: .day, value: -28, to: today) ?? today
        #else
        // The phone is the sole historical baseline producer. The watch only
        // reads recent samples and applies the phone's cached baseline.
        let historyStart = today
        #endif

        async let hrvResult = captured { try await self.hrvSamples(from: historyStart, to: now) }
        async let heartResult = captured { try await self.latestReading(.heartRate, type: .heartRate, unit: .count().unitDivided(by: .minute()), unitLabel: "bpm", before: now) }
        async let restingResult = captured { try await self.latestReading(.restingHeartRate, type: .restingHeartRate, unit: .count().unitDivided(by: .minute()), unitLabel: "bpm", before: now) }
        async let stepsResult = captured { try await self.steps(from: today, to: now) }
        async let sleepResult = captured { try await self.sleep(before: now, calendar: queryCalendar) }

        let hrv = await hrvResult
        let heart = await heartResult
        let resting = await restingResult
        let stepReading = await stepsResult
        let sleepReading = await sleepResult
        var readings: [MetricReading] = []
        var updatedBaseline: HRVBaseline?
        var trend: TrendResult?
        var dailyHistory: [DailyHRVPoint] = []

        switch hrv {
        case .success(let samples):
            // Prefer the most recently sampled Apple Watch source. An old
            // watch's history is never blended into a new watch's baseline.
            let sourceID = samples.max(by: { $0.timestamp < $1.timestamp })?.sourceID
            let selected = samples.filter { $0.sourceID == sourceID }
            let latest = selected.max(by: { $0.timestamp < $1.timestamp })
            readings.append(MetricReading(metric: .hrvSDNN, value: latest?.valueMilliseconds, unit: "ms", sampledAt: latest?.timestamp, sourceID: sourceID, state: latest == nil ? .noData : .available))
            if let sourceID {
                #if os(iOS)
                updatedBaseline = HRVEngine.makeBaseline(samples: selected, sourceID: sourceID, now: now, timeZone: timeZone)
                dailyHistory = HRVEngine.dailyHistory(samples: selected, sourceID: sourceID, now: now, timeZone: timeZone, days: 28)
                #else
                // A device/time-zone change requires a fresh baseline from the
                // phone; a locally computed substitute would mix semantics.
                if baseline?.sourceID == sourceID, baseline?.timeZoneIdentifier == timeZone.identifier {
                    updatedBaseline = baseline
                }
                #endif
                if let updatedBaseline {
                    trend = HRVEngine.assess(samples: selected, baseline: updatedBaseline, now: now, timeZone: timeZone)
                }
            }
        case .failure:
            readings.append(MetricReading(metric: .hrvSDNN, unit: "ms", state: .queryFailed))
            updatedBaseline = baseline
        }

        readings.append(reading(from: heart, metric: .heartRate, unit: "bpm"))
        readings.append(reading(from: resting, metric: .restingHeartRate, unit: "bpm"))
        readings.append(reading(from: stepReading, metric: .steps, unit: "steps"))
        readings.append(reading(from: sleepReading, metric: .sleep, unit: "hours"))
        return HealthSnapshot(generatedAt: now, timeZoneIdentifier: timeZone.identifier, isDemo: false, readings: readings, baseline: updatedBaseline, trend: trend, dailyHRV: dailyHistory)
    }

    /// HealthKit schedules these deliveries; this is not a sampling timer.
    /// Completion is always called, including query errors and coalesced updates.
    func startObserving(onChange: @escaping @Sendable () async -> Void) {
        observerLock.lock()
        guard observerQueries.isEmpty else { observerLock.unlock(); return }
        var types: [HKSampleType] = quantityTypes
        if let sleep = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.append(sleep) }
        let queries = types.map { type in
            HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                let token = HealthKitCompletion(completion)
                guard error == nil else { token.finish(); return }
                Task {
                    await onChange()
                    token.finish()
                }
            }
        }
        observerQueries = queries
        observerLock.unlock()
        for query in queries { healthStore.execute(query) }
        for type in types {
            healthStore.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    private func hrvSamples(from start: Date, to end: Date) async throws -> [HRVSample] {
        let samples = try await quantities(type: .heartRateVariabilitySDNN, from: start, to: end)
        return samples.compactMap { sample in
            let value = sample.quantity.doubleValue(for: .secondUnit(with: .milli))
            guard Self.isAppleWatch(sample), !Self.isUserEntered(sample), value.isFinite, value > 0 else { return nil }
            return HRVSample(id: sample.uuid, valueMilliseconds: value, timestamp: sample.startDate, sourceID: Self.sourceID(sample), isUserEntered: false)
        }
    }

    private func latestReading(_ metric: MetricKind, type: HKQuantityTypeIdentifier, unit: HKUnit, unitLabel: String, before now: Date) async throws -> MetricReading {
        // Bound the query rather than presenting a years-old measurement as
        // current. The precise timestamp is still part of every reading.
        let start = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let samples = try await quantities(type: type, from: start, to: now, limit: 100)
        let valid = samples.first { sample in
            let value = sample.quantity.doubleValue(for: unit)
            return !Self.isUserEntered(sample) && value.isFinite && value > 0 && Self.isAppleWatch(sample)
        }
        return MetricReading(metric: metric, value: valid?.quantity.doubleValue(for: unit), unit: unitLabel, sampledAt: valid?.startDate, sourceID: valid.map(Self.sourceID), state: valid == nil ? .noData : .available)
    }

    private func quantities(type identifier: HKQuantityTypeIdentifier, from start: Date, to end: Date, limit: Int = HKObjectQueryNoLimit) async throws -> [HKQuantitySample] {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return [] }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: limit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, results, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: results as? [HKQuantitySample] ?? []) }
            }
            healthStore.execute(query)
        }
    }

    private func steps(from start: Date, to end: Date) async throws -> MetricReading {
        guard let type = HKObjectType.quantityType(forIdentifier: .stepCount) else { return MetricReading(metric: .steps, unit: "steps", state: .noData) }
        let datePredicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let manualPredicate = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered, allowedValues: [true])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, NSCompoundPredicate(notPredicateWithSubpredicate: manualPredicate)])
        let totals: [StepTotal] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: [.cumulativeSum, .separateBySource]) { _, statistics, error in
                if let error { continuation.resume(throwing: error); return }
                let totals = (statistics?.sources ?? []).compactMap { source -> StepTotal? in
                    guard let value = statistics?.sumQuantity(for: source)?.doubleValue(for: .count()), value.isFinite, value >= 0 else { return nil }
                    return StepTotal(sourceID: source.bundleIdentifier, value: value)
                }
                continuation.resume(returning: totals)
            }
            healthStore.execute(query)
        }
        // Do not add phone/watch/third-party source totals: overlapping sources
        // would double-count. Prefer the largest Apple source, then the largest
        // remaining source. This conservative total can differ from Health's
        // private source-priority presentation and is documented in the app.
        let appleTotals = totals.filter { $0.sourceID.hasPrefix("com.apple.") }
        guard let chosen = (appleTotals.isEmpty ? totals : appleTotals).max(by: { $0.value < $1.value }) else {
            return MetricReading(metric: .steps, unit: "steps", state: .noData)
        }
        let samples = try await quantities(type: .stepCount, from: start, to: end, limit: HKObjectQueryNoLimit)
        let last = samples.first { $0.sourceRevision.source.bundleIdentifier == chosen.sourceID && !Self.isUserEntered($0) }
        return MetricReading(metric: .steps, value: chosen.value, unit: "steps", sampledAt: last?.endDate, sourceID: chosen.sourceID, state: .available)
    }

    private func sleep(before now: Date, calendar: Calendar) async throws -> MetricReading {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return MetricReading(metric: .sleep, unit: "hours", state: .noData) }
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterday),
              let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today) else {
            return MetricReading(metric: .sleep, unit: "hours", state: .noData)
        }
        let end = min(now, noon)
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end)
        let samples: [HKCategorySample] = try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: results as? [HKCategorySample] ?? []) }
            }
            healthStore.execute(query)
        }
        let asleepValues: Set<Int> = [HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue, HKCategoryValueSleepAnalysis.asleepCore.rawValue, HKCategoryValueSleepAnalysis.asleepDeep.rawValue, HKCategoryValueSleepAnalysis.asleepREM.rawValue]
        let asleep = samples.filter { asleepValues.contains($0.value) && !Self.isUserEntered($0) }
        let groups = Dictionary(grouping: asleep, by: Self.sourceID)
        let results = groups.map { source, values -> SleepTotal in
            let intervals = values.compactMap { sample -> DateInterval? in
                let left = max(start, sample.startDate)
                let right = min(end, sample.endDate)
                return right > left ? DateInterval(start: left, end: right) : nil
            }.sorted { $0.start < $1.start }
            var merged: [DateInterval] = []
            for interval in intervals {
                if let last = merged.last, interval.start <= last.end {
                    merged[merged.count - 1] = DateInterval(start: last.start, end: max(last.end, interval.end))
                } else { merged.append(interval) }
            }
            return SleepTotal(sourceID: source, seconds: merged.reduce(0) { $0 + $1.duration }, sampledAt: merged.last?.end, isAppleWatch: values.contains(where: Self.isAppleWatch))
        }.filter { $0.seconds > 0 }
        let watches = results.filter(\.isAppleWatch)
        guard let selected = (watches.isEmpty ? results : watches).max(by: { $0.seconds < $1.seconds }) else {
            return MetricReading(metric: .sleep, unit: "hours", state: .noData)
        }
        return MetricReading(metric: .sleep, value: selected.seconds / 3600, unit: "hours", sampledAt: selected.sampledAt, sourceID: selected.sourceID, state: .available)
    }

    private func reading(from result: Result<MetricReading, Error>, metric: MetricKind, unit: String) -> MetricReading {
        switch result {
        case .success(let reading): reading
        case .failure: MetricReading(metric: metric, unit: unit, state: .queryFailed)
        }
    }

    private static func isUserEntered(_ sample: HKSample) -> Bool {
        (sample.metadata?[HKMetadataKeyWasUserEntered] as? NSNumber)?.boolValue == true
    }

    private static func isAppleWatch(_ sample: HKSample) -> Bool {
        let product = sample.sourceRevision.productType ?? ""
        let model = sample.device?.model ?? ""
        return product.hasPrefix("Watch") || model.localizedCaseInsensitiveContains("watch")
    }

    private static func sourceID(_ sample: HKSample) -> String {
        // All keys are public APIs. SoftwareVersion is intentionally absent so
        // OS upgrades do not split the history. localIdentifier distinguishes
        // devices of the same model when HealthKit provides it.
        [sample.sourceRevision.source.bundleIdentifier, sample.sourceRevision.productType ?? sample.device?.model ?? "unknown", sample.device?.localIdentifier ?? ""]
            .joined(separator: "|")
    }
}

private struct StepTotal: Sendable {
    let sourceID: String
    let value: Double
}

private struct SleepTotal: Sendable {
    let sourceID: String
    let seconds: Double
    let sampledAt: Date?
    let isAppleWatch: Bool
}

private func captured<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T) async -> Result<T, Error> {
    do { return .success(try await operation()) }
    catch { return .failure(error) }
}

/// HKObserverQuery's completion closure predates Swift concurrency. This
/// wrapper only transfers its single invocation; it cannot run it twice.
private final class HealthKitCompletion: @unchecked Sendable {
    private let completion: () -> Void
    private let lock = NSLock()
    private var finished = false

    init(_ completion: @escaping () -> Void) { self.completion = completion }

    func finish() {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        completion()
    }
}

enum HealthProviderError: LocalizedError {
    case unavailable

    var errorDescription: String? { "这台设备暂不支持健康数据。可以继续体验演示模式。" }
}
