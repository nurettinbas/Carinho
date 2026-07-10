import Foundation
import WatchConnectivity

final class WatchConnectivityService: NSObject {
    nonisolated(unsafe) private static var instance: WatchConnectivityService?

    static var shared: WatchConnectivityService {
        if let instance { return instance }
        let service = WatchConnectivityService()
        instance = service
        return service
    }

    private let sessionDelegate = WatchConnectivitySessionDelegate()
    private var didActivate = false

    private override init() {
        super.init()
    }

    private func activateIfNeeded() {
        guard !didActivate else { return }
        didActivate = true
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = sessionDelegate
        session.activate()
    }

    func sendRecordingState(isRecording: Bool, isPaused: Bool = false, elapsed: TimeInterval, distanceMeters: Double) {
        activateIfNeeded()
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = [
            "isRecording": isRecording,
            "isPaused": isPaused,
            "elapsed": elapsed,
            "distance": distanceMeters
        ]
        try? WCSession.default.updateApplicationContext(payload)
    }
}

private final class WatchConnectivitySessionDelegate: NSObject, WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let action = message["action"] as? String else { return }
        DispatchQueue.main.async {
            switch action {
            case "start":
                NotificationCenter.default.post(name: .carinhoStartRecording, object: nil)
            case "stop":
                NotificationCenter.default.post(name: .carinhoStopRecording, object: nil)
            default:
                break
            }
        }
    }
}
