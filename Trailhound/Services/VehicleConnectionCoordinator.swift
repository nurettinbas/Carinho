import Foundation
import UIKit

enum VehicleConnectionTrigger: String, Codable, Equatable {
    case bluetooth
    case carPlay
}

/// Centralizes vehicle connect/disconnect events with debounce and persisted state.
/// Auto-start uses CarPlay only (scene or `.carAudio`). Classic Bluetooth audio
/// routes are ignored because they often appear only after media starts playing.
@MainActor
final class VehicleConnectionCoordinator {
    static let shared = VehicleConnectionCoordinator()

    private static let connectDebounceSeconds: TimeInterval = 1
    /// Locking the phone can temporarily tear down the app's CarPlay scene and hide
    /// `.carAudio` even though the head unit remains connected. Require sustained
    /// absence before ending a trip that was started by CarPlay.
    private static let activeCarPlayDisconnectPollSeconds: TimeInterval = 3
    private static let activeCarPlayDisconnectPollCount = 8

    private enum DefaultsKey {
        static let lastConnected = "vehicle.lastConnected"
        static let lastTrigger = "vehicle.lastTrigger"
    }

    private let settings: AppSettings
    private let defaults: UserDefaults
    private weak var recordingService: TripRecordingService?
    private weak var bluetoothService: BluetoothTriggerService?

    private var connectTask: Task<Void, Never>?
    private var disconnectTask: Task<Void, Never>?
    private var carPlayConnected = false
    /// Tracks whether we already nudged the user to set up auto-start for the
    /// current unpaired connection, so a single drive triggers at most one hint.
    private var pairingSuggestionShown = false

    private init(settings: AppSettings = .shared) {
        self.settings = settings
        defaults = UserDefaults(suiteName: "group.com.trailhound.app") ?? .standard
    }

    func configure(recordingService: TripRecordingService, bluetoothService: BluetoothTriggerService) {
        self.recordingService = recordingService
        self.bluetoothService = bluetoothService
    }

    func refreshLiveSnapshots() {
        let carPlayLive = carPlayLiveState()
        carPlayConnected = carPlayLive
        // Classic Bluetooth route matching is ignored for auto-start; still refresh
        // the BT service so `.carAudio` probes stay warm.
        _ = bluetoothService?.readConnectionState()
        syncSnapshot(carPlay: carPlayLive)
    }

    /// CarPlay is live if the CarPlay app scene is connected OR a `.carAudio`
    /// audio route is present (covers wired/wireless CarPlay without the
    /// Trailhound CarPlay app being opened in the car).
    private func carPlayLiveState() -> Bool {
        if CarPlayConnectionHandler.shared.readCarPlayConnectionState() { return true }
        if bluetoothService?.connectedCarPlayAudioCandidate() != nil { return true }
        return false
    }

    func reloadConfiguration() {
        refreshLiveSnapshots()
    }

    /// Marks an already-live vehicle connection as handled so pairing in the garage does not auto-start recording.
    func acknowledgeLiveConnectionWithoutRecording() {
        guard hasAutoTriggerVehicle else { return }

        let carPlayLive = settings.isPairedCarPlayVehicle && carPlayConnected
        guard carPlayLive else { return }

        connectTask?.cancel()
        connectTask = nil

        persistState(connected: true, trigger: .carPlay)
    }

    func handleBluetoothSnapshot(isConnected: Bool) {
        // Classic Bluetooth connect/disconnect must not drive auto-start. Re-probe
        // CarPlay only — `.carAudio` may appear via the same route-change path.
        DevLog.shared.log(.bluetooth, "handleBluetoothSnapshot(isConnected: \(isConnected)) ignored for auto-start; re-probing CarPlay")
        carPlayConnected = carPlayLiveState()
        syncSnapshot(carPlay: carPlayConnected)
    }

    func handleCarPlaySnapshot(isConnected: Bool) {
        DevLog.shared.log(.carPlay, "handleCarPlaySnapshot(isConnected: \(isConnected))")
        carPlayConnected = isConnected || carPlayLiveState()
        syncSnapshot(carPlay: carPlayConnected)
    }

    private func syncSnapshot(carPlay: Bool) {
        guard hasAutoTriggerVehicle else {
            cancelPendingTasks()
            persistState(connected: false, trigger: nil)
            suggestPairingIfNeeded(isConnected: carPlay)
            return
        }

        let carPlayLive = settings.isPairedCarPlayVehicle && carPlay

        if carPlayLive {
            // A live connection cancels any pending disconnect verification so a
            // momentary drop-and-reconnect does not end the trip.
            disconnectTask?.cancel()
            disconnectTask = nil

            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
            let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
            if persistedConnected, lastTrigger != nil {
                return
            }
            scheduleConnect(trigger: .carPlay)
        } else {
            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            guard persistedConnected else { return }
            scheduleDisconnect()
        }
    }

    private var hasAutoTriggerVehicle: Bool {
        settings.isPairedCarPlayVehicle
    }

    /// When no auto-start vehicle is configured, gently remind the user once per
    /// CarPlay connection that they can set one up. Resets on disconnect so a later
    /// drive (or a different car after unpairing) nudges again.
    private func suggestPairingIfNeeded(isConnected: Bool) {
        guard isConnected else {
            pairingSuggestionShown = false
            return
        }
        guard !pairingSuggestionShown else { return }
        pairingSuggestionShown = true
        TripNotificationService.notifyVehiclePairingSuggestion()
    }

    private func scheduleConnect(trigger: VehicleConnectionTrigger) {
        if disconnectTask != nil {
            DevLog.shared.log(.recording, "Cancelling pending disconnect: connect signal arrived (trigger=\(trigger.rawValue))")
        }
        disconnectTask?.cancel()
        disconnectTask = nil

        guard connectTask == nil else { return }

        DevLog.shared.log(.recording, "Scheduling connect (trigger=\(trigger.rawValue), debounce=\(Self.connectDebounceSeconds)s)")

        AutoRecordingEventLog.shared.noteVehicleConnectTrigger(
            channel: .carPlay,
            vehicleName: settings.pairedVehicleName
        )

        connectTask = Task { @MainActor [weak self] in
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VehicleConnect")
            defer {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
            try? await Task.sleep(for: .seconds(Self.connectDebounceSeconds))
            guard !Task.isCancelled, let self else { return }
            self.connectTask = nil
            self.applyConnect(trigger: trigger)
        }
    }

    private func scheduleDisconnect() {
        connectTask?.cancel()
        connectTask = nil

        guard disconnectTask == nil else { return }

        let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
        let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
        let pollSeconds = Self.activeCarPlayDisconnectPollSeconds
        let pollCount = Self.activeCarPlayDisconnectPollCount

        DevLog.shared.log(
            .recording,
            "Scheduling disconnect verification (lastTrigger=\(lastTrigger?.rawValue ?? "nil"), "
                + "pollSeconds=\(pollSeconds), pollCount=\(pollCount))"
        )

        disconnectTask = Task { @MainActor [weak self] in
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VehicleDisconnect")
            defer {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
            for attempt in 1...pollCount {
                try? await Task.sleep(for: .seconds(pollSeconds))
                guard !Task.isCancelled, let self else { return }

                let carPlayLive = self.settings.isPairedCarPlayVehicle && self.carPlayLiveState()
                DevLog.shared.log(
                    .recording,
                    "Disconnect verification attempt \(attempt)/\(pollCount): carPlayLive=\(carPlayLive)"
                )
                if carPlayLive {
                    DevLog.shared.log(.recording, "Disconnect cancelled: CarPlay live again on attempt \(attempt)")
                    self.carPlayConnected = true
                    self.disconnectTask = nil
                    return
                }
            }

            guard !Task.isCancelled, let self else { return }
            self.disconnectTask = nil

            DevLog.shared.warning(.recording, "Disconnect verification exhausted: applying disconnect (trigger=carPlay)")

            AutoRecordingEventLog.shared.noteVehicleDisconnectTrigger(channel: .carPlay)
            self.applyDisconnect()
        }
    }

    private func cancelPendingTasks() {
        connectTask?.cancel()
        connectTask = nil
        disconnectTask?.cancel()
        disconnectTask = nil
    }

    private func applyConnect(trigger: VehicleConnectionTrigger) {
        let wasConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
        if wasConnected {
            DevLog.shared.log(.recording, "applyConnect skipped: already connected (trigger=\(trigger.rawValue))")
            return
        }

        DevLog.shared.log(.recording, "applyConnect: persisting connected state (trigger=\(trigger.rawValue))")
        persistState(connected: true, trigger: .carPlay)
        recordingService?.handleVehicleConnected(trigger: .carPlay)
    }

    private func applyDisconnect() {
        let wasConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
        guard wasConnected else {
            DevLog.shared.log(.recording, "applyDisconnect skipped: not connected")
            return
        }

        DevLog.shared.log(.recording, "applyDisconnect: persisting disconnected state (trigger=carPlay)")
        persistState(connected: false, trigger: nil)
        recordingService?.handleVehicleDisconnected(trigger: .carPlay)
    }

    private func persistState(connected: Bool, trigger: VehicleConnectionTrigger?) {
        defaults.set(connected, forKey: DefaultsKey.lastConnected)
        defaults.set(trigger?.rawValue, forKey: DefaultsKey.lastTrigger)
    }
}
