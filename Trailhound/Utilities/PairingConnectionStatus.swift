import Foundation

@MainActor
enum PairingConnectionStatus {
    /// CarPlay is considered connected if the CarPlay app scene is live OR a
    /// `.carAudio` audio route is present (covers wired and wireless CarPlay
    /// even when the Trailhound CarPlay app has not been opened in the car).
    static func isCarPlayConnected(bluetoothService: BluetoothTriggerService? = nil) -> Bool {
        if CarPlayConnectionHandler.shared.readCarPlayConnectionState() { return true }
        if let bluetoothService, bluetoothService.connectedCarPlayAudioCandidate() != nil { return true }
        return false
    }

    static func isBluetoothAudioDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        bluetoothService.connectedCarCandidate() != nil
    }

    static func connectionSummary(for vehicle: VehicleProfile) -> String {
        // Auto-start is CarPlay-only; surface that channel in the pairing UI.
        if vehicle.autoTriggerCarPlayEnabled {
            return L10n.vehiclePairingCarPlay
        }
        return vehicle.channelSummaryText(
            carPlayLabel: L10n.vehiclePairingCarPlay,
            bluetoothLabel: L10n.vehiclePairingBluetooth
        )
    }

    static func isConnectionCurrentlyDetected(
        pairedVehicle: VehicleProfile?,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        if settings.hasAutoTriggerVehicle, let pairedVehicle {
            return isVehicleChannelConnected(
                vehicle: pairedVehicle,
                settings: settings,
                bluetoothService: bluetoothService
            )
        }
        return isCarPlayConnected(bluetoothService: bluetoothService)
    }

    static func detectedChannels(bluetoothService: BluetoothTriggerService) -> (carPlay: Bool, bluetooth: Bool) {
        (
            carPlay: isCarPlayConnected(bluetoothService: bluetoothService),
            bluetooth: isBluetoothAudioDetected(bluetoothService: bluetoothService)
        )
    }

    /// Auto-start pairing only cares about CarPlay (scene or `.carAudio`).
    static func isAnyConnectionDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        isCarPlayConnected(bluetoothService: bluetoothService)
    }

    static func isVehicleChannelConnected(
        vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        vehicle.autoTriggerCarPlayEnabled
            && isCarPlayConnected(bluetoothService: bluetoothService)
    }

    /// Live Bluetooth route matches this vehicle's stored identity (pairing not required yet).
    static func isBluetoothLinkedToVehicle(
        _ vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        guard let candidate = bluetoothService.connectedCarCandidate() else { return false }
        let identity = BluetoothPairingIdentity(
            uid: vehicle.bluetoothTriggerUID,
            displayName: vehicle.bluetoothTriggerDisplayName ?? vehicle.name,
            legacyIdentifier: vehicle.bluetoothTriggerIdentifier
                ?? vehicle.bluetoothID
                ?? vehicle.connectionIdentifier
        )
        return BluetoothRouteMatcher.matches(
            candidate: candidate,
            pairing: identity
        )
    }

    static func shouldOfferVehicleConfirmation(
        for vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        // Only offer Auto Start when CarPlay is actually live.
        guard isCarPlayConnected(bluetoothService: bluetoothService) else { return false }
        if settings.hasAutoTriggerVehicle,
           settings.activeAutoTriggerVehicleID != vehicle.id {
            return false
        }
        return !isVehicleChannelConnected(
            vehicle: vehicle,
            settings: settings,
            bluetoothService: bluetoothService
        )
    }
}
