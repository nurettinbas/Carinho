import AVFoundation
import Foundation

/// Monitors the audio route for the paired vehicle's Bluetooth audio connection.
/// A live connection means the paired route (`uid` / name match) is present.
///
/// Detection reads `currentRoute` first, then `availableInputs`, so a route that
/// is connected but not actively playing is still recognized without the user
/// having to start music or navigation first.
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

    @discardableResult
    func readConnectionState() -> Bool {
        evaluateCurrentRoute(reportSnapshot: false)
        return isCarConnected
    }

    func selectCar(uid: String?, name: String) {
        settings.pairVehicle(uid: uid, name: name)
        syncRouteSnapshot()
    }

    func clearSelectedCar() {
        settings.clearPairedVehicle()
        isCarConnected = false
        currentAudioRouteName = nil
        lastMatchMethod = nil
        onRouteSnapshotChanged?(false)
    }

    /// Pairing UI: the primary connected car audio device (first car port).
    /// Keep this simple — auto-start pairing depends on this stable "what's connected now" signal.
    func connectedCarCandidate() -> BluetoothRouteCandidate? {
        let session = AVAudioSession.sharedInstance()

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
            guard let candidate = makeCandidate(from: port) else { continue }
            return candidate
        }
        return nil
    }

    /// Live / disconnect checks scan every car-audio port. Cars often expose
    /// separate HFP and A2DP endpoints with different UIDs; matching only the
    /// first port causes a false disconnect when the active profile flips.
    private func allCarCandidates() -> [BluetoothRouteCandidate] {
        let session = AVAudioSession.sharedInstance()
        var ports = session.currentRoute.outputs + session.currentRoute.inputs
        if let available = session.availableInputs {
            ports.append(contentsOf: available)
        }

        var seen = Set<String>()
        var candidates: [BluetoothRouteCandidate] = []
        for port in ports {
            guard let candidate = makeCandidate(from: port) else { continue }
            let key = candidate.uid ?? candidate.normalizedName
            guard seen.insert(key).inserted else { continue }
            candidates.append(candidate)
        }
        return candidates
    }

    private func makeCandidate(from port: AVAudioSessionPortDescription) -> BluetoothRouteCandidate? {
        guard isCarAudioPort(port.portType) else { return nil }
        let name = port.portName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let uid = port.uid.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
        return BluetoothRouteCandidate(
            uid: uid,
            name: name,
            portTypeLabel: portTypeLabel(for: port.portType)
        )
    }

    private func isCarAudioPort(_ portType: AVAudioSession.Port) -> Bool {
        switch portType {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .carAudio:
            return true
        default:
            return false
        }
    }

    private func portTypeLabel(for portType: AVAudioSession.Port) -> String {
        switch portType {
        case .bluetoothA2DP: "A2DP"
        case .bluetoothHFP: "HFP"
        case .bluetoothLE: "LE"
        case .carAudio: "CarAudio"
        default: portType.rawValue
        }
    }

    private func startMonitoring() {
        let observer = RouteChangeObserver()
        observer.service = self
        observer.startObserving(session: AVAudioSession.sharedInstance())
        routeObserver = observer

        evaluateCurrentRoute(reportSnapshot: true)
    }

    fileprivate func evaluateCurrentRoute(reportSnapshot: Bool) {
        // Pairing banner still shows the primary connected device.
        currentAudioRouteName = connectedCarCandidate()?.name

        guard settings.pairedRouteUID != nil else {
            lastMatchMethod = nil
            let wasConnected = isCarConnected
            isCarConnected = false
            guard reportSnapshot, wasConnected else { return }
            onRouteSnapshotChanged?(false)
            return
        }

        let identity = settings.pairingIdentity
        var matchMethod: BluetoothRouteMatchMethod?
        var matchedCandidate: BluetoothRouteCandidate?

        for candidate in allCarCandidates() {
            if let method = BluetoothRouteMatcher.match(candidate: candidate, pairing: identity) {
                matchMethod = method
                matchedCandidate = candidate
                break
            }
        }

        if let matchedCandidate, let matchMethod {
            learnPairedUIDIfNeeded(from: matchedCandidate, method: matchMethod)
        }

        lastMatchMethod = matchMethod

        let wasConnected = isCarConnected
        isCarConnected = matchMethod != nil

        guard reportSnapshot else { return }
        if isCarConnected != wasConnected {
            DevLog.shared.log(
                .bluetooth,
                "Route match -> connected=\(isCarConnected) method=\(String(describing: matchMethod)) name=\(matchedCandidate?.name ?? "nil") uid=\(matchedCandidate?.uid ?? "nil")"
            )
            onRouteSnapshotChanged?(isCarConnected)
        }
    }

    /// When the car flips HFP↔A2DP the UID often changes while the display name
    /// stays the same. Persist the newly seen UID so later checks match by uid.
    private func learnPairedUIDIfNeeded(
        from candidate: BluetoothRouteCandidate,
        method: BluetoothRouteMatchMethod
    ) {
        guard method == .name || method == .legacyIdentifier else { return }
        guard let uid = candidate.uid, !uid.isEmpty else { return }
        guard settings.pairedRouteUID != uid else { return }

        DevLog.shared.log(
            .bluetooth,
            "Learning paired route UID \(uid) (was \(settings.pairedRouteUID ?? "nil")) via \(method)"
        )
        settings.pairedRouteUID = uid
        if let name = candidate.name.nonEmpty {
            settings.pairedVehicleName = name
        }
        syncLearnedUIDToActiveVehicle(uid: uid, name: candidate.name)
    }

    /// Keep the SwiftData vehicle profile in sync with AppSettings so the pairing
    /// UI subtitle does not drift after an HFP↔A2DP UID learn.
    private func syncLearnedUIDToActiveVehicle(uid: String, name: String) {
        guard let vehicleID = settings.activeAutoTriggerVehicleID else { return }
        let context = AppServices.modelContainer.mainContext
        guard let vehicle = VehicleResolver.vehicle(withID: vehicleID, in: context) else { return }
        vehicle.pairedRouteUID = uid
        if let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty {
            vehicle.pairedRouteName = trimmed
        }
        try? context.save()
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
