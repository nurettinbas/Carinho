import AVFoundation
import Foundation

@MainActor
@Observable
final class BluetoothTriggerService {
    private(set) var isCarConnected = false
    private(set) var currentAudioRouteName: String?

    var onRouteSnapshotChanged: ((Bool) -> Void)?

    private let settings: AppSettings
    @ObservationIgnored nonisolated(unsafe) private var routeObserver: RouteChangeObserver?

    init(settings: AppSettings = .shared, activateImmediately: Bool = false) {
        self.settings = settings
        if activateImmediately {
            startMonitoring()
        }
    }

    func activate() {
        guard routeObserver == nil else { return }
        startMonitoring()
    }

    deinit {
        routeObserver?.stopObserving()
    }

    func refreshMonitoring() {
        syncRouteSnapshot()
    }

    func syncRouteSnapshot() {
        evaluateCurrentRoute(reportSnapshot: true)
    }

    func selectCar(identifier: String, name: String) {
        settings.pairVehicle(id: identifier, name: name, type: .bluetoothAudio)
        syncRouteSnapshot()
    }

    func clearSelectedCar() {
        settings.clearPairedVehicle()
        isCarConnected = false
        currentAudioRouteName = nil
        onRouteSnapshotChanged?(false)
    }

    /// Returns the currently connected car audio device for pairing UI.
    func connectedCarCandidate() -> (id: String, name: String)? {
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs {
            guard isCarAudioPort(output.portType) else { continue }
            let name = output.portName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            return (id: routeIdentifier(for: output), name: name)
        }
        return nil
    }

    private func startMonitoring() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let observer = RouteChangeObserver()
        observer.service = self
        observer.startObserving(session: session)
        routeObserver = observer

        evaluateCurrentRoute(reportSnapshot: true)
    }

    fileprivate func evaluateCurrentRoute(reportSnapshot: Bool) {
        let candidate = connectedCarCandidate()
        currentAudioRouteName = candidate?.name

        guard let selectedID = settings.pairedVehicleID,
              settings.pairedVehicleType == .bluetoothAudio else {
            if isCarConnected {
                isCarConnected = false
                if reportSnapshot {
                    onRouteSnapshotChanged?(false)
                }
            }
            return
        }

        let matched = candidate.map { routeMatches(selectedID: selectedID, candidateID: $0.id) } ?? false
        let wasConnected = isCarConnected
        isCarConnected = matched

        guard reportSnapshot else { return }
        if matched != wasConnected || matched {
            onRouteSnapshotChanged?(matched)
        }
    }

    private func routeMatches(selectedID: String, candidateID: String) -> Bool {
        if selectedID == candidateID { return true }
        // Legacy pairings stored normalized display names.
        return selectedID == normalizedRouteID(candidateID)
            || normalizedRouteID(selectedID) == candidateID
    }

    private func routeIdentifier(for output: AVAudioSessionPortDescription) -> String {
        if let uid = output.uid.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            return uid
        }
        return normalizedRouteID(output.portName)
    }

    private func isCarAudioPort(_ portType: AVAudioSession.Port) -> Bool {
        switch portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio:
            return true
        default:
            return false
        }
    }

    private func normalizedRouteID(_ name: String) -> String {
        name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}

private final class RouteChangeObserver: NSObject {
    weak var service: BluetoothTriggerService?

    func startObserving(session: AVAudioSession) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc nonisolated private func handleRouteChange(_ notification: Notification) {
        Task { @MainActor [weak service] in
            service?.evaluateCurrentRoute(reportSnapshot: true)
        }
    }
}
