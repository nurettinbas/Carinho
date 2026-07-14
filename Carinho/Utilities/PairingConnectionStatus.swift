import Foundation

@MainActor
enum PairingConnectionStatus {
    /// CarPlay is considered connected if the CarPlay app scene is live OR a
    /// `.carAudio` audio route is present (covers wired and wireless CarPlay
    /// even when the Carinho CarPlay app has not been opened in the car).
    static func isCarPlayConnected(bluetoothService: BluetoothTriggerService? = nil) -> Bool {
        if CarPlayConnectionHandler.shared.readCarPlayConnectionState() { return true }
        if let bluetoothService, bluetoothService.connectedCarPlayAudioCandidate() != nil { return true }
        return false
    }

    static func isBluetoothAudioDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        bluetoothService.connectedCarCandidate() != nil
    }

    static func connectionSummary(for vehicle: VehicleProfile) -> String {
        vehicle.channelSummaryText(
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
            || isBluetoothAudioDetected(bluetoothService: bluetoothService)
    }

    static func detectedChannels(bluetoothService: BluetoothTriggerService) -> (carPlay: Bool, bluetooth: Bool) {
        (
            carPlay: isCarPlayConnected(bluetoothService: bluetoothService),
            bluetooth: isBluetoothAudioDetected(bluetoothService: bluetoothService)
        )
    }

    static func isAnyConnectionDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        let channels = detectedChannels(bluetoothService: bluetoothService)
        return channels.carPlay || channels.bluetooth
    }

    static func isVehicleChannelConnected(
        vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        let carPlay = vehicle.autoTriggerCarPlayEnabled && isCarPlayConnected(bluetoothService: bluetoothService)
        let bluetooth = vehicle.autoTriggerBluetoothEnabled
            && isBluetoothLinkedToVehicle(vehicle, settings: settings, bluetoothService: bluetoothService)
        if vehicle.autoTriggerCarPlayEnabled && vehicle.autoTriggerBluetoothEnabled {
            return carPlay || bluetooth
        }
        if vehicle.autoTriggerCarPlayEnabled { return carPlay }
        if vehicle.autoTriggerBluetoothEnabled { return bluetooth }
        return false
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
        guard isAnyConnectionDetected(bluetoothService: bluetoothService) else { return false }
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
