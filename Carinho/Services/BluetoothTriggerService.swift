import AVFoundation
import Foundation

@MainActor
@Observable
final class BluetoothTriggerService {
    private(set) var isCarConnected = false
    private(set) var currentAudioRouteName: String?
    private(set) var lastMatchMethod: BluetoothRouteMatchMethod?

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
        activate()
        syncRouteSnapshot()
    }

    func syncRouteSnapshot() {
        evaluateCurrentRoute(reportSnapshot: true)
    }

    func selectCar(uid: String?, identifier: String, name: String) {
        settings.pairVehicle(uid: uid, legacyIdentifier: identifier, name: name, type: .bluetoothAudio)
        syncRouteSnapshot()
    }

    func clearSelectedCar() {
        settings.clearPairedVehicle()
        isCarConnected = false
        currentAudioRouteName = nil
        lastMatchMethod = nil
        onRouteSnapshotChanged?(false)
    }

    /// Returns the currently connected car audio device for pairing UI.
    func connectedCarCandidate() -> BluetoothRouteCandidate? {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(
            .playback,
            mode: .default,
            options: [.allowBluetoothHFP, .allowBluetoothA2DP, .mixWithOthers]
        )
        try? session.setActive(true)

        if let active = firstCarCandidate(
            in: session.currentRoute.outputs + session.currentRoute.inputs
        ) {
            return active
        }

        if let available = session.availableInputs,
           let parked = firstCarCandidate(in: available) {
            return parked
        }

        return nil
    }

    private func firstCarCandidate(in ports: [AVAudioSessionPortDescription]) -> BluetoothRouteCandidate? {
        for port in ports {
            guard isCarAudioPort(port.portType) else { continue }
            let name = port.portName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            let uid = port.uid.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
            return BluetoothRouteCandidate(
                uid: uid,
                name: name,
                portTypeLabel: portTypeLabel(for: port.portType)
            )
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

        guard settings.pairedBluetoothChannelEnabled else {
            if isCarConnected {
                isCarConnected = false
                lastMatchMethod = nil
                if reportSnapshot {
                    onRouteSnapshotChanged?(false)
                }
            }
            return
        }

        let matchMethod = candidate.flatMap { routeMatchMethod(for: $0) }
        lastMatchMethod = matchMethod
        let matched = matchMethod != nil

        if let candidate, let matchMethod {
            learnPairedIdentityIfNeeded(from: candidate, method: matchMethod)
        }

        let wasConnected = isCarConnected
        isCarConnected = matched

        guard reportSnapshot else { return }
        if matched != wasConnected || matched {
            onRouteSnapshotChanged?(matched)
        }
    }

    private func routeMatchMethod(for candidate: BluetoothRouteCandidate) -> BluetoothRouteMatchMethod? {
        BluetoothRouteMatcher.match(
            candidate: candidate,
            pairing: settings.bluetoothPairingIdentity,
            allowLastKnownVehicleFallback: settings.activeAutoTriggerVehicleID != nil
        )
    }

    private func learnPairedIdentityIfNeeded(
        from candidate: BluetoothRouteCandidate,
        method: BluetoothRouteMatchMethod
    ) {
        guard method == .name || method == .legacyIdentifier || method == .lastKnownVehicle else { return }
        guard let uid = candidate.uid else { return }
        settings.learnPairedBluetoothUID(uid)
    }

    private func portTypeLabel(for portType: AVAudioSession.Port) -> String {
        switch portType {
        case .bluetoothHFP: return "HFP"
        case .bluetoothA2DP: return "A2DP"
        case .bluetoothLE: return "LE"
        case .carAudio: return "CarAudio"
        default: return portType.rawValue
        }
    }

    private func isCarAudioPort(_ portType: AVAudioSession.Port) -> Bool {
        switch portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio:
            return true
        default:
            return false
        }
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
