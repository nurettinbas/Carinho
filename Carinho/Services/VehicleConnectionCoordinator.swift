import Foundation

enum VehicleConnectionTrigger: String, Codable, Equatable {
    case bluetooth
    case carPlay
}

/// Centralizes vehicle connect/disconnect events with debounce and persisted state.
@MainActor
final class VehicleConnectionCoordinator {
    static let shared = VehicleConnectionCoordinator()

    private static let connectDebounceSeconds: TimeInterval = 2
    private static let disconnectDebounceSeconds: TimeInterval = 5

    private enum DefaultsKey {
        static let lastConnected = "vehicle.lastConnected"
        static let lastTrigger = "vehicle.lastTrigger"
    }

    private let settings: AppSettings
    private let defaults: UserDefaults
    private weak var recordingService: TripRecordingService?

    private var connectTask: Task<Void, Never>?
    private var disconnectTask: Task<Void, Never>?
    private var bluetoothConnected = false
    private var carPlayConnected = false

    private init(settings: AppSettings = .shared) {
        self.settings = settings
        defaults = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
    }

    func configure(recordingService: TripRecordingService) {
        self.recordingService = recordingService
    }

    func reloadConfiguration() {
        syncSnapshot(bluetooth: bluetoothConnected, carPlay: carPlayConnected)
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
        syncSnapshot(bluetooth: isConnected, carPlay: carPlayConnected)
    }

    func handleCarPlaySnapshot(isConnected: Bool) {
        carPlayConnected = isConnected
        syncSnapshot(bluetooth: bluetoothConnected, carPlay: isConnected)
    }

    private func syncSnapshot(bluetooth: Bool, carPlay: Bool) {
        guard hasAutoTriggerVehicle else {
            cancelPendingTasks()
            persistState(connected: false, trigger: nil)
            return
        }

        let carPlayLive = settings.isPairedCarPlayVehicle && carPlay
        let bluetoothLive = settings.isPairedBluetoothVehicle && bluetooth
        let isAnyConnected = carPlayLive || bluetoothLive

        if isAnyConnected {
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
        let channel: AutoRecordingEventChannel = lastTrigger == .carPlay ? .carPlay : .bluetooth
        AutoRecordingEventLog.shared.noteVehicleDisconnectTrigger(channel: channel)

        disconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.disconnectDebounceSeconds))
            guard !Task.isCancelled, let self else { return }
            self.disconnectTask = nil

            let carPlayLive = self.settings.isPairedCarPlayVehicle && self.carPlayConnected
            let bluetoothLive = self.settings.isPairedBluetoothVehicle && self.bluetoothConnected
            guard !(carPlayLive || bluetoothLive) else { return }

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
