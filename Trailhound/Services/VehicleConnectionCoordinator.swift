import Foundation
import UIKit

enum VehicleConnectionTrigger: String, Codable, Equatable {
    case bluetooth
}

/// Centralizes vehicle connect/disconnect events with debounce and persisted state.
/// Auto-start uses the paired Bluetooth audio route (uid match).
@MainActor
final class VehicleConnectionCoordinator {
    static let shared = VehicleConnectionCoordinator()

    private static let connectDebounceSeconds: TimeInterval = 1
    /// A brief route drop (e.g. handoff between HFP/A2DP) can momentarily hide the
    /// paired route even though the car stays connected. Require sustained absence
    /// before ending a trip that was started automatically.
    private static let disconnectPollSeconds: TimeInterval = 3
    private static let disconnectPollCount = 8
    /// Ignore disconnect signals briefly after a connect so GPS/audio route
    /// churn right when recording starts does not end the trip.
    private static let postConnectDisconnectGraceSeconds: TimeInterval = 45

    /// Unit-test overrides (`nil` = production default).
    static var testDisconnectGraceSeconds: TimeInterval?
    static var testDisconnectPollSeconds: TimeInterval?
    static var testDisconnectPollCount: Int?

    private static var effectiveGraceSeconds: TimeInterval {
        testDisconnectGraceSeconds ?? postConnectDisconnectGraceSeconds
    }

    private static var effectivePollSeconds: TimeInterval {
        testDisconnectPollSeconds ?? disconnectPollSeconds
    }

    private static var effectivePollCount: Int {
        testDisconnectPollCount ?? disconnectPollCount
    }

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
    /// Waits out the post-connect grace window, then starts disconnect verification
    /// if the route is still gone (so a single early `false` snapshot is not lost).
    private var graceDisconnectTask: Task<Void, Never>?
    private var vehicleConnected = false
    private var lastConnectEstablishedAt: Date?
    /// After manual stop while the route is still live, wait for one real disconnect
    /// before auto-start can fire again (clears stuck `lastConnected` otherwise).
    private var awaitingReconnectAfterManualStop = false
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

    /// Clears in-memory session state between unit tests (`shared` is a singleton).
    func resetSessionStateForTesting() {
        connectTask?.cancel()
        connectTask = nil
        cancelDisconnectWork()
        vehicleConnected = false
        lastConnectEstablishedAt = nil
        awaitingReconnectAfterManualStop = false
        pairingSuggestionShown = false
        persistState(connected: false, trigger: nil)
    }

    func refreshLiveSnapshots() {
        let live = vehicleLiveState()
        vehicleConnected = live
        // Passive refreshes (location wake / foreground) may still schedule *connect*
        // when the paired route is live — that path worked. They must not schedule
        // *disconnect*: a transient false read right after recording starts was ending trips.
        if live {
            if disconnectTask != nil || graceDisconnectTask != nil {
                DevLog.shared.log(.recording, "Disconnect cancelled: live route on passive refresh")
            }
            cancelDisconnectWork()
            syncSnapshot(connected: true)
        }
        // When live == false: update in-memory flag only; wait for an explicit
        // handleVehicleSnapshot(false) from a route-change before disconnecting.
    }

    /// The paired vehicle is live when its Bluetooth audio route (uid match) is present.
    private func vehicleLiveState() -> Bool {
        bluetoothService?.readConnectionState() ?? false
    }

    func reloadConfiguration() {
        refreshLiveSnapshots()
    }

    /// Clears the handled-connect session after a manual stop so the next real
    /// vehicle reconnect can auto-start. While the route stays live, blocks restart.
    func notifyManualRecordingStopped() {
        let stillInVehicleSession = vehicleConnected || vehicleLiveState()
        awaitingReconnectAfterManualStop = stillInVehicleSession
        connectTask?.cancel()
        connectTask = nil
        persistState(connected: false, trigger: nil)
        DevLog.shared.log(
            .recording,
            "Manual stop: cleared connect session (awaitingReconnect=\(stillInVehicleSession))"
        )
    }

    /// Marks an already-live vehicle connection as handled so pairing in the garage does not auto-start recording.
    func acknowledgeLiveConnectionWithoutRecording() {
        guard hasAutoTriggerVehicle, vehicleConnected else { return }

        connectTask?.cancel()
        connectTask = nil

        lastConnectEstablishedAt = Date()
        persistState(connected: true, trigger: .bluetooth)
    }

    func handleVehicleSnapshot(isConnected: Bool) {
        DevLog.shared.log(.bluetooth, "handleVehicleSnapshot(isConnected: \(isConnected))")

        if !isConnected, connectTask != nil {
            DevLog.shared.log(
                .bluetooth,
                "Ignoring transient disconnect during connect debounce"
            )
            vehicleConnected = vehicleLiveState()
            return
        }

        if !isConnected {
            awaitingReconnectAfterManualStop = false
        }

        vehicleConnected = isConnected || vehicleLiveState()
        syncSnapshot(connected: vehicleConnected)
    }

    private func syncSnapshot(connected: Bool) {
        guard hasAutoTriggerVehicle else {
            cancelPendingTasks()
            persistState(connected: false, trigger: nil)
            suggestPairingIfNeeded(isConnected: connected)
            return
        }

        if connected {
            // A live connection cancels any pending disconnect verification so a
            // momentary drop-and-reconnect does not end the trip.
            cancelDisconnectWork()

            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            let lastTriggerRaw = defaults.string(forKey: DefaultsKey.lastTrigger)
            let lastTrigger = lastTriggerRaw.flatMap(VehicleConnectionTrigger.init(rawValue:))
            if persistedConnected, lastTrigger != nil {
                return
            }
            scheduleConnect(trigger: .bluetooth)
        } else {
            let persistedConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
            guard persistedConnected else { return }
            scheduleDisconnect()
        }
    }

    private var hasAutoTriggerVehicle: Bool {
        settings.hasAutoTriggerVehicle
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
        if awaitingReconnectAfterManualStop {
            DevLog.shared.log(
                .recording,
                "Connect deferred: awaiting vehicle disconnect after manual stop"
            )
            return
        }

        if disconnectTask != nil || graceDisconnectTask != nil {
            DevLog.shared.log(.recording, "Cancelling pending disconnect: connect signal arrived (trigger=\(trigger.rawValue))")
        }
        cancelDisconnectWork()

        guard connectTask == nil else { return }

        DevLog.shared.log(.recording, "Scheduling connect (trigger=\(trigger.rawValue), debounce=\(Self.connectDebounceSeconds)s)")

        AutoRecordingEventLog.shared.noteVehicleConnectTrigger(
            channel: .bluetooth,
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
        if connectTask != nil {
            DevLog.shared.log(.recording, "Disconnect ignored: connect debounce in flight")
            return
        }

        connectTask?.cancel()
        connectTask = nil

        if let remainingGrace = remainingPostConnectGraceSeconds() {
            scheduleGraceDeferredDisconnect(remainingSeconds: remainingGrace)
            return
        }

        beginDisconnectVerification()
    }

    private func remainingPostConnectGraceSeconds() -> TimeInterval? {
        guard let establishedAt = lastConnectEstablishedAt else { return nil }
        let elapsed = Date().timeIntervalSince(establishedAt)
        let remaining = Self.effectiveGraceSeconds - elapsed
        guard remaining > 0 else { return nil }
        return remaining
    }

    private func scheduleGraceDeferredDisconnect(remainingSeconds: TimeInterval) {
        guard graceDisconnectTask == nil else { return }

        DevLog.shared.log(
            .recording,
            "Disconnect deferred: re-check in \(String(format: "%.1f", remainingSeconds))s after post-connect grace"
        )

        graceDisconnectTask = Task { @MainActor [weak self] in
            let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "VehicleDisconnectGrace")
            defer {
                if backgroundTask != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                }
            }
            try? await Task.sleep(for: .seconds(remainingSeconds))
            guard !Task.isCancelled, let self else { return }
            self.graceDisconnectTask = nil

            if self.vehicleLiveState() {
                DevLog.shared.log(.recording, "Disconnect cancelled after grace: vehicle live again")
                return
            }

            guard self.defaults.bool(forKey: DefaultsKey.lastConnected) else { return }

            DevLog.shared.log(.recording, "Post-connect grace elapsed: starting disconnect verification")
            self.beginDisconnectVerification()
        }
    }

    private func beginDisconnectVerification() {
        guard disconnectTask == nil else { return }

        let pollSeconds = Self.effectivePollSeconds
        let pollCount = Self.effectivePollCount

        DevLog.shared.log(
            .recording,
            "Scheduling disconnect verification (pollSeconds=\(pollSeconds), pollCount=\(pollCount))"
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

                let live = self.vehicleLiveState()
                DevLog.shared.log(
                    .recording,
                    "Disconnect verification attempt \(attempt)/\(pollCount): live=\(live)"
                )
                if live {
                    DevLog.shared.log(.recording, "Disconnect cancelled: vehicle live again on attempt \(attempt)")
                    self.vehicleConnected = true
                    self.disconnectTask = nil
                    return
                }
            }

            guard !Task.isCancelled, let self else { return }
            self.disconnectTask = nil

            DevLog.shared.warning(.recording, "Disconnect verification exhausted: applying disconnect (trigger=bluetooth)")

            AutoRecordingEventLog.shared.noteVehicleDisconnectTrigger(channel: .bluetooth)
            self.applyDisconnect()
        }
    }

    private func cancelDisconnectWork() {
        graceDisconnectTask?.cancel()
        graceDisconnectTask = nil
        disconnectTask?.cancel()
        disconnectTask = nil
    }

    private func cancelPendingTasks() {
        connectTask?.cancel()
        connectTask = nil
        cancelDisconnectWork()
    }

    private func applyConnect(trigger: VehicleConnectionTrigger) {
        let wasConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
        if wasConnected {
            DevLog.shared.log(.recording, "applyConnect skipped: already connected (trigger=\(trigger.rawValue))")
            return
        }

        DevLog.shared.log(.recording, "applyConnect: persisting connected state (trigger=\(trigger.rawValue))")
        lastConnectEstablishedAt = Date()
        persistState(connected: true, trigger: .bluetooth)
        recordingService?.handleVehicleConnected(trigger: .bluetooth)
    }

    private func applyDisconnect() {
        let wasConnected = defaults.bool(forKey: DefaultsKey.lastConnected)
        guard wasConnected else {
            DevLog.shared.log(.recording, "applyDisconnect skipped: not connected")
            return
        }

        DevLog.shared.log(.recording, "applyDisconnect: persisting disconnected state (trigger=bluetooth)")
        lastConnectEstablishedAt = nil
        persistState(connected: false, trigger: nil)
        recordingService?.handleVehicleDisconnected(trigger: .bluetooth)
    }

    private func persistState(connected: Bool, trigger: VehicleConnectionTrigger?) {
        defaults.set(connected, forKey: DefaultsKey.lastConnected)
        defaults.set(trigger?.rawValue, forKey: DefaultsKey.lastTrigger)
    }
}
