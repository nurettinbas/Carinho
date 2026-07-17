import Foundation

@MainActor
enum PairingConnectionStatus {
    /// A Bluetooth car audio route is currently connected. Used to decide when to
    /// offer auto-start pairing in the garage.
    static func isVehicleConnected(bluetoothService: BluetoothTriggerService) -> Bool {
        bluetoothService.connectedCarCandidate() != nil
    }

    static func isAnyConnectionDetected(bluetoothService: BluetoothTriggerService) -> Bool {
        isVehicleConnected(bluetoothService: bluetoothService)
    }

    static func connectionSummary(for vehicle: VehicleProfile) -> String {
        if let name = vehicle.pairedRouteName, !name.isEmpty {
            return name
        }
        return L10n.vehiclePairingBluetooth
    }

    /// True when the given vehicle is the one bound to the currently connected route.
    /// Prefers AppSettings identity for the active auto-start vehicle (may have learned
    /// a newer HFP/A2DP UID than the SwiftData copy briefly lags).
    static func isVehicleChannelConnected(
        vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        guard vehicle.autoStartEnabled || settings.activeAutoTriggerVehicleID == vehicle.id else {
            return false
        }
        guard let candidate = bluetoothService.connectedCarCandidate() else { return false }

        let identity: BluetoothPairingIdentity
        if settings.activeAutoTriggerVehicleID == vehicle.id {
            identity = settings.pairingIdentity
        } else {
            identity = BluetoothPairingIdentity(
                uid: vehicle.pairedRouteUID,
                displayName: vehicle.pairedRouteName
            )
        }
        return BluetoothRouteMatcher.matches(candidate: candidate, pairing: identity)
    }

    /// Offer Auto-start only when Bluetooth is live and no vehicle is armed yet.
    /// Once a vehicle is the active auto-start target, never re-offer — even if the
    /// live HFP/A2DP port briefly fails a first-port match after a tab switch.
    static func shouldOfferVehicleConfirmation(
        for vehicle: VehicleProfile,
        settings: AppSettings = .shared,
        bluetoothService: BluetoothTriggerService
    ) -> Bool {
        guard isVehicleConnected(bluetoothService: bluetoothService) else { return false }
        // Already armed (this vehicle or another): show Remove on the active row only.
        if settings.hasAutoTriggerVehicle { return false }
        return true
    }
}
