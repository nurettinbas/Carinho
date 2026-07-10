import Foundation
import SwiftData

enum VehicleResolver {
    @MainActor
    static func resolveActiveVehicle(
        in context: ModelContext,
        trigger: VehicleRecordingTrigger,
        settings: AppSettings = .shared
    ) -> VehicleProfile? {
        let vehicles = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
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

    static func assign(vehicle: VehicleProfile?, to trip: Trip) {
        trip.vehicle = vehicle
        trip.vehicleID = vehicle?.id
    }
}

enum VehicleRecordingTrigger {
    case manual
    case automatic
    case carPlay
    case bluetooth
}
