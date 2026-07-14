import Foundation
import UIKit

enum VehicleConnectionTrigger: String, Codable, Equatable {
    case bluetooth
    case carPlay
}

/// Centralizes vehicle connect/disconnect events with debounce and persisted state.
@MainActor
final class VehicleConnectionCoordinator {
    static let shared = VehicleConnectionCoordinator()

    private static let connectDebounceSeconds: TimeInterval = 1
    /// Short verification window before finalizing a disconnect. Guards against a
    /// momentary audio-route drop (e.g. parked with no playback) ending the trip.
    private static let disconnectDebounceSeconds: TimeInterval = 3

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
    private var bluetoothConnected = false
    private var carPlayConnected = false
    /// Tracks whether we already nudged the user to set up auto-start for the
    /// current unpaired connection, so a single drive triggers at most one hint.
    private var pairingSuggestionShown = false

    private init(settings: AppSettings = .shared) {
        self.settings = settings
        defaults = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
    }

    func configure(recordingService: TripRecordingService, bluetoothService: BluetoothTriggerService) {
        self.recordingService = recordingService
        self.bluetoothService = bluetoothService
    }

    func refreshLiveSnapshots() {
        let carPlayLive = carPlayLiveState()
        let bluetoothLive = bluetoothService?.readConnectionState() ?? false
        bluetoothConnected = bluetoothLive
        carPlayConnected = carPlayLive
        syncSnapshot(bluetooth: bluetoothLive, carPlay: carPlayLive)
    }

    /// CarPlay is live if the CarPlay app scene is connected OR a `.carAudio`
    /// audio route is present (covers wired/wireless CarPlay without the
    /// Carinho CarPlay app being opened in the car).
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
        let bluetoothLive = settings.isPairedBluetoothVehicle && bluetoothConnected
        guard carPlayLive || bluetoothLive else { return }

        connectTask?.cancel()
        connectTask = nil

        let trigger: VehicleConnectionTrigger = carPlayLive ? .carPlay : .bluetooth
        persistState(connected: true, trigger: trigger)
    }

    func handleBluetoothSnapshot(isConnected: Bool) {
        bluetoothConnected = isConnected
        carPlayConnected = carPlayLiveState()
        syncSnapshot(bluetooth: bluetoothConnected, carPlay: carPlayConnected)
    }

    func handleCarPlaySnapshot(isConnected: Bool) {
        carPlayConnected = isConnected || carPlayLiveState()
        bluetoothConnected = bluetoothService?.readConnectionState() ?? false
        syncSnapshot(bluetooth: bluetoothConnected, carPlay: carPlayConnected)
    }

    private func syncSnapshot(bluetooth: Bool, carPlay: Bool) {
        guard hasAutoTriggerVehicle else {
            cancelPendingTasks()
            persistState(connected: false, trigger: nil)
            suggestPairingIfNeeded(isConnected: bluetooth || carPlay)
            return
        }

        let carPlayLive = settings.isPairedCarPlayVehicle && carPlay
        let bluetoothLive = settings.isPairedBluetoothVehicle && bluetooth
        let isAnyConnected = carPlayLive || bluetoothLive

        if isAnyConnected {
            // A live connection cancels any pending disconnect verification so a
            // momentary drop-and-reconnect does not end the trip.
            disconnectTask?.cancel()
            disconnectTask = nil

            let trigger: VehicleConnectionTrigger = carPlayLive ? .carPlay : .bluetooth
            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
            let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
            if persistedConnected, lastTrigger != nil {
                return
            }
            scheduleConnect(trigger: trigger)
        } else {
            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            guard persistedConnected else { return }
            scheduleDisconnect()
        }
    }

    private var hasAutoTriggerVehicle: Bool {
        settings.isPairedBluetoothVehicle || settings.isPairedCarPlayVehicle
    }

    /// When no auto-start vehicle is configured, gently remind the user once per
    /// connection that they can set one up. Resets on disconnect so a later drive
    /// (or a different car after unpairing) nudges again.
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
        disconnectTask?.cancel()
        disconnectTask = nil

        guard connectTask == nil else { return }

        let channel: AutoRecordingEventChannel = trigger == .carPlay ? .carPlay : .bluetooth
        AutoRecordingEventLog.shared.noteVehicleConnectTrigger(
            channel: channel,
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

        disconnectTask = Task { @MainActor [weak self] in
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VehicleDisconnect")
            defer {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
            try? await Task.sleep(for: .seconds(Self.disconnectDebounceSeconds))
            guard !Task.isCancelled, let self else { return }
            self.disconnectTask = nil

            // Re-probe: if the paired vehicle is connected again, the drop was
            // momentary. Keep recording and refresh the live snapshot.
            let carPlayLive = self.settings.isPairedCarPlayVehicle && self.carPlayLiveState()
            let bluetoothLive = self.settings.isPairedBluetoothVehicle
                && (self.bluetoothService?.readConnectionState() ?? false)
            if carPlayLive || bluetoothLive {
                self.carPlayConnected = carPlayLive
                self.bluetoothConnected = bluetoothLive
                return
            }

            let lastTriggerRaw = self.defaults.string(forKey: DefaultsKey.lastTrigger)
            let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
            let channel: AutoRecordingEventChannel = lastTrigger == .carPlay ? .carPlay : .bluetooth
            AutoRecordingEventLog.shared.noteVehicleDisconnectTrigger(channel: channel)

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
        if wasConnected { return }

        persistState(connected: true, trigger: trigger)

        switch trigger {
        case .bluetooth:
            recordingService?.handleVehicleConnected(trigger: .bluetooth)
        case .carPlay:
            recordingService?.handleVehicleConnected(trigger: .carPlay)
        }
    }

    private func applyDisconnect() {
        let wasConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
        guard wasConnected else { return }

        let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
        let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))

        persistState(connected: false, trigger: nil)

        switch lastTrigger {
        case .bluetooth:
            recordingService?.handleVehicleDisconnected(trigger: .bluetooth)
        case .carPlay:
            recordingService?.handleVehicleDisconnected(trigger: .carPlay)
        case nil:
            break
        }
    }

    private func persistState(connected: Bool, trigger: VehicleConnectionTrigger?) {
        defaults.set(connected, forKey: DefaultsKey.lastConnected)
        defaults.set(trigger?.rawValue, forKey: DefaultsKey.lastTrigger)
    }
}
