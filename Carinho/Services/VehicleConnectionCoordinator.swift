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

        let trigger: VehicleConnectionTrigger?
        let isConnected: Bool

        if settings.isPairedCarPlayVehicle, carPlay {
            trigger = .carPlay
            isConnected = true
        } else if settings.isPairedBluetoothVehicle, bluetooth {
            trigger = .bluetooth
            isConnected = true
        } else {
            trigger = nil
            isConnected = false
        }

        if isConnected, let trigger {
            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
            let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
            if persistedConnected, lastTrigger == trigger {
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

        disconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(Self.disconnectDebounceSeconds))
            guard !Task.isCancelled, let self else { return }
            self.disconnectTask = nil
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
        let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
        let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))

        if wasConnected, lastTrigger == trigger {
            return
        }

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
