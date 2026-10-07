import Foundation
import Observation
import WristGroveCore

@MainActor
@Observable
final class AppModel {
    private(set) var snapshot: HealthSnapshot?
    private(set) var isDemo = true
    private(set) var isRefreshing = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let store = SnapshotStore()
    @ObservationIgnored private let healthProvider = HealthKitDataProvider()
    @ObservationIgnored private let demoProvider = MockHealthDataProvider()
    @ObservationIgnored private let connectivity = WatchConnectivityService()
    @ObservationIgnored private var hasStartedObservers = false

    init() {
        isDemo = store.isDemo
        snapshot = store.loadForWidget()
        connectivity.start { [weak self] incoming in
            self?.receive(incoming)
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        errorMessage = nil
        isDemo = store.isDemo

        do {
            let cached = try store.load(isDemo: isDemo)
            let provider: any HealthDataProvider = isDemo ? demoProvider : healthProvider
            let incoming = try await provider.fetchSnapshot(at: Date(), baseline: cached?.baseline)
            let merged = SnapshotMerger.merge(local: cached, incoming: incoming, now: Date())
            try store.save(merged)
            snapshot = merged
            connectivity.send(merged)
            startObservingIfNeeded()
        } catch {
            errorMessage = userMessage(error)
            snapshot = store.loadForWidget()
            if !isDemo {
                startObservingIfNeeded()
            }
        }
    }

    /// Permission is requested only after an explicit user action. HealthKit
    /// does not report read-denial status, so success only starts a fresh query.
    func connectHealth() async {
        isRefreshing = true
        defer { isRefreshing = false }
        store.setDemoMode(false, updatedAt: Date())
        isDemo = false
        snapshot = try? store.load(isDemo: false)
        errorMessage = nil
        do {
            try await healthProvider.requestAuthorization()
            startObservingIfNeeded()
            await refreshAfterConnection()
        } catch {
            errorMessage = userMessage(error)
            snapshot = store.loadForWidget()
        }
    }

    func setDemoMode(_ enabled: Bool) async {
        store.setDemoMode(enabled, updatedAt: Date())
        isDemo = enabled
        snapshot = store.loadForWidget()
        errorMessage = nil
        if enabled {
            await refresh()
        } else if snapshot == nil {
            errorMessage = GroveCopy.text(
                "连接 Apple 健康后查看自己的记录。",
                "Connect Apple Health to see your readings."
            )
        }
    }

    func clearLocalSnapshots() {
        store.deleteSnapshots()
        snapshot = nil
        errorMessage = nil
    }

    private func receive(_ incoming: HealthSnapshot) {
        // The phone controls the active mode. A context from the other mode
        // cannot enter this device's currently selected local snapshot.
        if store.isDemo != incoming.isDemo {
            let timestamp = Date()
            store.setDemoMode(incoming.isDemo, updatedAt: timestamp)
        }
        guard let cached = try? store.load(isDemo: incoming.isDemo) else {
            snapshot = incoming
            try? store.save(incoming)
            isDemo = incoming.isDemo
            return
        }
        let merged = SnapshotMerger.merge(local: cached, incoming: incoming, now: Date())
        try? store.save(merged)
        snapshot = merged
        isDemo = incoming.isDemo
    }

    private func startObservingIfNeeded() {
        guard !isDemo, !hasStartedObservers else { return }
        hasStartedObservers = true
        #if os(iOS)
        healthProvider.startObserving { [weak self] in
            await self?.refresh()
        }
        #endif
    }

    private func refreshAfterConnection() async {
        // Avoid the public guard in connectHealth while it holds the refreshing state.
        do {
            let cached = try store.load(isDemo: false)
            let incoming = try await healthProvider.fetchSnapshot(at: Date(), baseline: cached?.baseline)
            let merged = SnapshotMerger.merge(local: cached, incoming: incoming, now: Date())
            try store.save(merged)
            snapshot = merged
            connectivity.send(merged)
        } catch {
            errorMessage = userMessage(error)
        }
    }

    private func userMessage(_ error: Error) -> String {
        if let localized = error as? LocalizedError, let message = localized.errorDescription {
            return message
        }
        return GroveCopy.text("暂时无法读取健康数据，请稍后重试。", "Health data is temporarily unavailable. Try again later.")
    }
}
