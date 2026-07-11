import Foundation

@MainActor
enum PairingConnectionStatus {
    static func isCarPlayConnected() -> Bool {
        CarPlayConnectionHandler.shared.isConnected
    }

    static func isBluetoothRouteMatched(settings: AppSettings = .shared, bluetoothService: BluetoothTriggerService) -> Bool {
        guard settings.pairedBluetoothChannelEnabled else { return false }
        guard let candidate = bluetoothService.connectedCarCandidate() else { return false }
        return BluetoothRouteMatcher.matches(
            candidate: candidate,
            pairing: settings.bluetoothPairingIdentity,
            allowLastKnownVehicleFallback: settings.activeAutoTriggerVehicleID != nil
        )
    }

    static func isBluetoothAudioDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        bluetoothService.connectedCarCandidate() != nil
    }

    /// Pairing UI: audio route detected, or already paired and matched.
    static func isBluetoothReadyForPairing(
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        if isBluetoothRouteMatched(settings: settings, bluetoothService: bluetoothService) {
            return true
        }
        return isBluetoothAudioDetected(bluetoothService: bluetoothService)
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
        return isCarPlayConnected() || isBluetoothAudioDetected(bluetoothService: bluetoothService)
    }

    static func detectedChannels(bluetoothService: BluetoothTriggerService) -> (carPlay: Bool, bluetooth: Bool) {
        (
            carPlay: isCarPlayConnected(),
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
        let carPlay = vehicle.autoTriggerCarPlayEnabled && isCarPlayConnected()
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
            pairing: identity,
            allowLastKnownVehicleFallback: false
        )
    }

    static func shouldOfferVehicleConfirmation(
        for vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        guard isAnyConnectionDetected(bluetoothService: bluetoothService) else { return false }
        return !isVehicleChannelConnected(
            vehicle: vehicle,
            settings: settings,
            bluetoothService: bluetoothService
        )
    }
}
