import Foundation
import WidgetKit
import WristGroveCore

/// App Groups share data only between targets on one device. WatchConnectivity
/// is responsible for transport between the phone and the watch.
final class SnapshotStore: @unchecked Sendable {
    static let appGroupID = "group.io.github.jeanbai0818cloud.wristgrove"
    private static let staleAfter: TimeInterval = 4 * 60 * 60

    private let directory: URL
    private let defaults: UserDefaults
    private let lock = NSLock()

    init() {
        defaults = UserDefaults(suiteName: Self.appGroupID) ?? .standard
        let manager = FileManager.default
        #if os(iOS) || os(watchOS)
        let groupContainer = manager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupID)
        #else
        let groupContainer: URL? = nil
        #endif
        // The fallback lets unentitled previews and simulators run. It cannot
        // share a snapshot with a widget, and is never a transport mechanism.
        let fallback = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = (groupContainer ?? fallback).appendingPathComponent("WristGrove", isDirectory: true)
    }

    var isDemo: Bool {
        defaults.object(forKey: "isDemo") == nil ? true : defaults.bool(forKey: "isDemo")
    }

    var settingsUpdatedAt: Date {
        Date(timeIntervalSince1970: defaults.double(forKey: "settingsUpdatedAt"))
    }

    func setDemoMode(_ enabled: Bool, updatedAt: Date) {
        defaults.set(enabled, forKey: "isDemo")
        defaults.set(updatedAt.timeIntervalSince1970, forKey: "settingsUpdatedAt")
    }

    func load(isDemo: Bool) throws -> HealthSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        let url = fileURL(isDemo: isDemo)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let snapshot = try JSONDecoder().decode(HealthSnapshot.self, from: Data(contentsOf: url))
        guard snapshot.schemaVersion == HealthSnapshot.currentSchemaVersion, snapshot.isDemo == isDemo else {
            throw SnapshotStoreError.invalidSnapshot
        }
        return snapshot
    }

    func save(_ snapshot: HealthSnapshot) throws {
        guard snapshot.schemaVersion == HealthSnapshot.currentSchemaVersion else {
            throw SnapshotStoreError.invalidSnapshot
        }
        lock.lock()
        defer { lock.unlock() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        #if os(iOS) || os(watchOS)
        try data.write(to: fileURL(isDemo: snapshot.isDemo), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: fileURL(isDemo: snapshot.isDemo), options: .atomic)
        #endif
        WidgetCenter.shared.reloadAllTimelines()
    }

    func deleteSnapshots() {
        lock.lock()
        defer { lock.unlock() }
        for mode in [true, false] {
            try? FileManager.default.removeItem(at: fileURL(isDemo: mode))
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Widgets use only the current mode's file and never fall back to the other
    /// mode. A failed query keeps its previous value but retains queryFailed.
    func loadForWidget(at date: Date = Date()) -> HealthSnapshot? {
        guard let cached = try? load(isDemo: isDemo) else { return nil }
        guard date.timeIntervalSince(cached.generatedAt) > Self.staleAfter else { return cached }
        let readings = cached.readings.map { reading in
            MetricReading(
                metric: reading.metric,
                value: reading.value,
                unit: reading.unit,
                sampledAt: reading.sampledAt,
                sourceID: reading.sourceID,
                state: reading.state == .available ? .stale : reading.state
            )
        }
        return HealthSnapshot(
            schemaVersion: cached.schemaVersion,
            generatedAt: cached.generatedAt,
            timeZoneIdentifier: cached.timeZoneIdentifier,
            isDemo: cached.isDemo,
            readings: readings,
            baseline: cached.baseline,
            trend: cached.trend,
            dailyHRV: cached.dailyHRV
        )
    }

    private func fileURL(isDemo: Bool) -> URL {
        directory.appendingPathComponent(isDemo ? "demo-snapshot.json" : "health-snapshot.json")
    }
}

enum SnapshotStoreError: LocalizedError {
    case invalidSnapshot

    var errorDescription: String? {
        "本地摘要的版本或数据模式不匹配，请刷新数据。"
    }
}
