import Foundation
import SwiftData

enum VehicleResolver {
    @MainActor
    static func resolveActiveVehicle(
        in context: ModelContext,
        trigger: VehicleRecordingTrigger,
        settings: AppSettings = .shared
    ) -> VehicleProfile? {
        let vehicles = fetchVehicles(in: context)
        guard !vehicles.isEmpty else { return nil }

        if let activeID = settings.activeAutoTriggerVehicleID,
           let active = vehicles.first(where: { $0.id == activeID }) {
            return active
        }

        switch trigger {
        case .carPlay:
            if let match = vehicles.first(where: { $0.connectionKind == .carPlay }) { return match }
            if let match = vehicles.first(where: { $0.carPlayFlag }) { return match }
        case .bluetooth:
            let identity = settings.bluetoothPairingIdentity
            if let match = vehicles.first(where: { vehicle in
                matchesBluetoothVehicle(vehicle, identity: identity)
            }) {
                return match
            }
            if let pairedID = settings.pairedVehicleID,
               let match = vehicles.first(where: {
                   $0.connectionIdentifier == pairedID || $0.bluetoothID == pairedID
               }) {
                return match
            }
        case .manual, .automatic:
            break
        }

        return vehicles.first(where: \.isDefault) ?? vehicles.first
    }

    static func vehicle(withID id: UUID, in context: ModelContext) -> VehicleProfile? {
        fetchVehicles(in: context).first { $0.id == id }
    }

    static func assign(vehicle: VehicleProfile?, to trip: Trip) {
        trip.vehicleID = vehicle?.id
        trip.vehicle = nil
    }

    private static func fetchVehicles(in context: ModelContext) -> [VehicleProfile] {
        (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
    }

    private static func matchesBluetoothVehicle(
        _ vehicle: VehicleProfile,
        identity: BluetoothPairingIdentity
    ) -> Bool {
        guard vehicle.autoTriggerBluetoothEnabled else { return false }
        if let uid = identity.uid, vehicle.bluetoothTriggerUID == uid { return true }
        if let legacy = identity.legacyIdentifier {
            if vehicle.bluetoothTriggerIdentifier == legacy { return true }
            if vehicle.bluetoothID == legacy { return true }
            if vehicle.connectionIdentifier == legacy { return true }
        }
        if let pairedName = identity.normalizedName,
           let vehicleName = vehicle.bluetoothTriggerDisplayName.map(BluetoothRouteCandidate.normalize),
           pairedName == vehicleName {
            return true
        }
        return false
    }
}

enum VehicleRecordingTrigger {
    case manual
    case automatic
    case carPlay
    case bluetooth
}
