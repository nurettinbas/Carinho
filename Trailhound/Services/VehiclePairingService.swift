import Foundation
import SwiftData

@MainActor
enum VehiclePairingService {
    /// Binds a vehicle to the currently connected Bluetooth route so that route's
    /// connect/disconnect drives auto-start. Only one vehicle can be armed at a time.
    static func pair(
        vehicle: VehicleProfile,
        candidate: BluetoothRouteCandidate,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        clearAutoTrigger(from: fetchVehicles(in: context), except: vehicle.id)

        let routeUID = candidate.uid ?? candidate.normalizedName
        vehicle.autoStartEnabled = true
        vehicle.pairedRouteUID = routeUID
        vehicle.pairedRouteName = candidate.name

        setDefaultVehicle(vehicle, in: context, save: false)
        settings.activeAutoTriggerVehicleID = vehicle.id
        settings.pairVehicle(uid: routeUID, name: candidate.name)

        try? context.save()
        VehicleConnectionCoordinator.shared.acknowledgeLiveConnectionWithoutRecording()
        reloadConnectionMonitoring()
    }

    static func unpair(
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let vehicles = fetchVehicles(in: context)
        if let activeID = settings.activeAutoTriggerVehicleID,
           let vehicle = vehicles.first(where: { $0.id == activeID }) {
            vehicle.autoStartEnabled = false
            vehicle.pairedRouteUID = nil
            vehicle.pairedRouteName = nil
        }
        settings.clearPairedVehicle()
        settings.activeAutoTriggerVehicleID = nil
        try? context.save()
        reloadConnectionMonitoring()
    }

    static func deleteVehicle(
        _ vehicle: VehicleProfile,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let wasDefault = vehicle.isDefault
        if settings.activeAutoTriggerVehicleID == vehicle.id {
            unpair(in: context, settings: settings)
        }
        context.delete(vehicle)
        do {
            try context.save()
            if wasDefault, let next = fetchVehicles(in: context).first {
                setDefaultVehicle(next, in: context)
            }
        } catch {
            AppErrorPresenter.shared.present(L10n.pairingTabDeleteFailed(error.localizedDescription))
        }
    }

    static func isActivelyPaired(vehicleID: UUID, settings: AppSettings = .shared) -> Bool {
        settings.hasAutoTriggerVehicle && settings.activeAutoTriggerVehicleID == vehicleID
    }

    static func setDefaultVehicle(
        _ vehicle: VehicleProfile,
        in context: ModelContext,
        save: Bool = true
    ) {
        for item in fetchVehicles(in: context) {
            item.isDefault = item.id == vehicle.id
        }
        if save {
            try? context.save()
        }
    }

    static func seedDefaultVehicleIfNeeded(
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let vehicles = fetchVehicles(in: context)
        guard vehicles.isEmpty else { return }

        let vehicle = VehicleProfile(
            name: L10n.vehicleDefaultName,
            consumption: settings.fuelLitersPer100km
        )
        context.insert(vehicle)
        setDefaultVehicle(vehicle, in: context)
    }

    static func detectLiveConnection(bluetoothService: BluetoothTriggerService) -> LiveVehicleConnection {
        LiveVehicleConnection(candidate: bluetoothService.connectedCarCandidate())
    }

    static func confirmLiveConnection(
        vehicle: VehicleProfile,
        live: LiveVehicleConnection,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        guard let candidate = live.candidate else {
            AppErrorPresenter.shared.present(L10n.pairingTabWaitingConnection)
            return
        }
        pair(vehicle: vehicle, candidate: candidate, in: context, settings: settings)
    }

    private static func fetchVehicles(in context: ModelContext) -> [VehicleProfile] {
        (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
    }

    private static func clearAutoTrigger(from vehicles: [VehicleProfile], except keepID: UUID) {
        for vehicle in vehicles where vehicle.id != keepID && vehicle.autoStartEnabled {
            vehicle.autoStartEnabled = false
            vehicle.pairedRouteUID = nil
            vehicle.pairedRouteName = nil
        }
    }

    private static func reloadConnectionMonitoring() {
        AppServices.runtime.bluetoothService.syncRouteSnapshot()
        AppServices.runtime.tripRecordingService.startServices()
    }
}

struct LiveVehicleConnection: Equatable {
    let candidate: BluetoothRouteCandidate?

    var isDetected: Bool {
        candidate != nil
    }

    func displayLabel() -> String {
        guard let candidate else { return L10n.pairingLiveConnectionNone }
        return L10n.pairingConnectionBluetooth(candidate.name, candidate.portTypeLabel)
    }
}
