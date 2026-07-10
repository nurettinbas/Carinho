import Foundation
import SwiftData

@MainActor
enum VehiclePairingService {
    static func migrateLegacyPairingIfNeeded(in context: ModelContext, settings: AppSettings = .shared) {
        guard settings.hasAutoTriggerVehicle else { return }

        let vehicles = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        if let activeID = settings.activeAutoTriggerVehicleID,
           vehicles.contains(where: { $0.id == activeID }) {
            mirrorActiveVehicleToSettings(vehicles: vehicles, settings: settings)
            return
        }

        if let existing = vehicles.first(where: { vehicle in
            guard let pairedID = settings.pairedVehicleID else { return false }
            switch settings.pairedVehicleType {
            case .carPlay:
                return vehicle.connectionKind == .carPlay
            case .bluetoothAudio:
                return vehicle.bluetoothID == pairedID || vehicle.connectionIdentifier == pairedID
            case .none:
                return false
            }
        }) {
            settings.activeAutoTriggerVehicleID = existing.id
            syncVehicleConnection(from: settings, to: existing)
            try? context.save()
            return
        }

        let name = settings.pairedVehicleName ?? L10n.vehicleDefaultName
        let vehicle = VehicleProfile(
            name: name,
            consumption: settings.fuelLitersPer100km,
            isDefault: vehicles.isEmpty
        )
        syncVehicleConnection(from: settings, to: vehicle)
        context.insert(vehicle)
        settings.activeAutoTriggerVehicleID = vehicle.id
        try? context.save()
    }

    static func pair(
        vehicle: VehicleProfile,
        kind: VehicleConnectionKind,
        identifier: String,
        displayName: String,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        clearAutoTrigger(from: (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? [], except: vehicle.id)

        vehicle.connectionKind = kind
        vehicle.connectionIdentifier = identifier
        vehicle.connectionDisplayName = displayName
        vehicle.syncLegacyConnectionFields()

        settings.activeAutoTriggerVehicleID = vehicle.id
        mirrorVehicleToSettings(vehicle, settings: settings)

        try? context.save()
        VehicleConnectionCoordinator.shared.reloadConfiguration()
        AppServices.runtime.bluetoothService.syncRouteSnapshot()
    }

    static func unpair(
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let vehicles = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        if let activeID = settings.activeAutoTriggerVehicleID,
           let vehicle = vehicles.first(where: { $0.id == activeID }) {
            vehicle.connectionKind = .none
            vehicle.syncLegacyConnectionFields()
        }
        settings.clearPairedVehicle()
        settings.activeAutoTriggerVehicleID = nil
        try? context.save()
        AppServices.runtime.bluetoothService.syncRouteSnapshot()
        VehicleConnectionCoordinator.shared.reloadConfiguration()
    }

    static func activeVehicle(in context: ModelContext, settings: AppSettings = .shared) -> VehicleProfile? {
        let vehicles = (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
        if let activeID = settings.activeAutoTriggerVehicleID {
            return vehicles.first { $0.id == activeID }
        }
        return nil
    }

    private static func syncVehicleConnection(from settings: AppSettings, to vehicle: VehicleProfile) {
        switch settings.pairedVehicleType {
        case .carPlay:
            vehicle.connectionKind = .carPlay
            vehicle.connectionIdentifier = VehicleConnectionKind.carPlayVehicleID
            vehicle.connectionDisplayName = settings.pairedVehicleName ?? "CarPlay"
        case .bluetoothAudio:
            vehicle.connectionKind = .bluetooth
            vehicle.connectionIdentifier = settings.pairedVehicleID
            vehicle.connectionDisplayName = settings.pairedVehicleName
        case .none:
            break
        }
        vehicle.syncLegacyConnectionFields()
    }

    private static func mirrorActiveVehicleToSettings(vehicles: [VehicleProfile], settings: AppSettings) {
        guard let id = settings.activeAutoTriggerVehicleID,
              let vehicle = vehicles.first(where: { $0.id == id }) else { return }
        mirrorVehicleToSettings(vehicle, settings: settings)
    }

    private static func mirrorVehicleToSettings(_ vehicle: VehicleProfile, settings: AppSettings) {
        switch vehicle.connectionKind {
        case .carPlay:
            settings.pairVehicle(
                id: vehicle.connectionIdentifier ?? VehicleConnectionKind.carPlayVehicleID,
                name: vehicle.connectionDisplayName ?? "CarPlay",
                type: .carPlay
            )
        case .bluetooth:
            guard let identifier = vehicle.connectionIdentifier else { return }
            settings.pairVehicle(
                id: identifier,
                name: vehicle.connectionDisplayName ?? vehicle.name,
                type: .bluetoothAudio
            )
        case .none:
            break
        }
    }

    private static func clearAutoTrigger(from vehicles: [VehicleProfile], except keepID: UUID) {
        for vehicle in vehicles where vehicle.id != keepID && vehicle.hasAutoTriggerConnection {
            vehicle.connectionKind = .none
            vehicle.syncLegacyConnectionFields()
        }
    }
}
