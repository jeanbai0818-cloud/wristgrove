import Foundation
@preconcurrency import WatchConnectivity
import WristGroveCore

@MainActor
final class WatchConnectivityService: NSObject {
    private(set) var activationError: String?
    private var onSnapshot: (@MainActor @Sendable (HealthSnapshot) -> Void)?

    func start(receiving handler: @escaping @MainActor @Sendable (HealthSnapshot) -> Void) {
        onSnapshot = handler
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        if let data = session.receivedApplicationContext["snapshot"] as? Data {
            decodeAndDeliver(data)
        }
    }

    func send(_ snapshot: HealthSnapshot) {
        #if os(iOS)
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              let data = try? JSONEncoder().encode(snapshot) else { return }
        do {
            try WCSession.default.updateApplicationContext([
                "snapshot": data,
                "schemaVersion": snapshot.schemaVersion,
                "demo": snapshot.isDemo
            ])
        } catch {
            activationError = error.localizedDescription
        }
        #endif
    }

    private func decodeAndDeliver(_ data: Data) {
        guard let snapshot = try? JSONDecoder().decode(HealthSnapshot.self, from: data) else { return }
        onSnapshot?(snapshot)
    }
}

extension WatchConnectivityService: @preconcurrency WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {
        guard let error else { return }
        Task { @MainActor [weak self] in self?.activationError = error.localizedDescription }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let data = applicationContext["snapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(HealthSnapshot.self, from: data) else { return }
        Task { @MainActor [weak self] in self?.onSnapshot?(snapshot) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif
}
