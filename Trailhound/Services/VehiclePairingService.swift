import Foundation
import SwiftData

@MainActor
enum VehiclePairingService {
    static func migrateLegacyPairingIfNeeded(in context: ModelContext, settings: AppSettings = .shared) {
        mergeDuplicateCarPlayProfiles(in: context, settings: settings)
        clearBluetoothOnlyAutoStartIfNeeded(in: context, settings: settings)
        repairStaleActivePairing(in: context, settings: settings)

        let vehicles = fetchVehicles(in: context)
        for vehicle in vehicles {
            vehicle.migrateLegacyTriggerFlagsIfNeeded()
            vehicle.syncLegacyConnectionFields()
        }
        try? context.save()

        if let activeID = settings.activeAutoTriggerVehicleID,
           let vehicle = vehicles.first(where: { $0.id == activeID }),
           let uid = settings.pairedBluetoothUID,
           vehicle.bluetoothTriggerUID != uid {
            vehicle.bluetoothTriggerUID = uid
            vehicle.bluetoothTriggerIdentifier = uid
            vehicle.syncLegacyConnectionFields()
            try? context.save()
        }

        guard settings.hasAutoTriggerVehicle || settings.activeAutoTriggerVehicleID != nil else { return }

        if let activeID = settings.activeAutoTriggerVehicleID,
           let vehicle = vehicles.first(where: { $0.id == activeID }) {
            mirrorVehicleToSettings(vehicle, settings: settings)
            setDefaultVehicle(vehicle, in: context, save: false)
            try? context.save()
            return
        }

        if let existing = vehicles.first(where: { vehicle in
            guard let pairedID = settings.pairedVehicleID else { return false }
            if settings.pairedCarPlayChannelEnabled, vehicle.autoTriggerCarPlayEnabled { return true }
            if settings.pairedBluetoothChannelEnabled {
                return matchesBluetoothVehicle(vehicle, pairedID: pairedID, settings: settings)
            }
            switch settings.pairedVehicleType {
            case .carPlay:
                return vehicle.autoTriggerCarPlayEnabled
            case .bluetoothAudio:
                return matchesBluetoothVehicle(vehicle, pairedID: pairedID, settings: settings)
            case .none:
                return false
            }
        }) {
            settings.activeAutoTriggerVehicleID = existing.id
            syncVehicleConnection(from: settings, to: existing)
            try? context.save()
            mirrorVehicleToSettings(existing, settings: settings)
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
        mirrorVehicleToSettings(vehicle, settings: settings)
    }

    static func syncLearnedBluetoothUID(in context: ModelContext, settings: AppSettings = .shared) {
        guard let activeID = settings.activeAutoTriggerVehicleID,
              let uid = settings.pairedBluetoothUID,
              let vehicle = fetchVehicles(in: context).first(where: { $0.id == activeID }),
              vehicle.bluetoothTriggerUID != uid else { return }
        vehicle.bluetoothTriggerUID = uid
        vehicle.bluetoothTriggerIdentifier = uid
        vehicle.syncLegacyConnectionFields()
        try? context.save()
    }

    static func repairStaleActivePairing(in context: ModelContext, settings: AppSettings = .shared) {
        guard let activeID = settings.activeAutoTriggerVehicleID else { return }
        let vehicles = fetchVehicles(in: context)
        guard let vehicle = vehicles.first(where: { $0.id == activeID }) else {
            settings.activeAutoTriggerVehicleID = nil
            settings.clearPairedVehicle()
            return
        }
        guard settings.hasAutoTriggerVehicle else {
            settings.activeAutoTriggerVehicleID = nil
            settings.clearPairedVehicle()
            vehicle.autoTriggerCarPlayEnabled = false
            vehicle.autoTriggerBluetoothEnabled = false
            vehicle.syncLegacyConnectionFields()
            try? context.save()
            return
        }

        // Auto-start is CarPlay-only; never re-arm classic Bluetooth as a trigger.
        vehicle.autoTriggerCarPlayEnabled = true
        vehicle.autoTriggerBluetoothEnabled = false
        vehicle.syncLegacyConnectionFields()
        mirrorVehicleToSettings(vehicle, settings: settings)
        try? context.save()
    }

    /// Clears legacy Bluetooth-only auto-start pairings. Classic BT audio routes
    /// are not a reliable connect signal, so auto-start requires CarPlay.
    static func clearBluetoothOnlyAutoStartIfNeeded(
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let vehicles = fetchVehicles(in: context)
        var didChange = false

        for vehicle in vehicles where vehicle.autoTriggerBluetoothEnabled && !vehicle.autoTriggerCarPlayEnabled {
            vehicle.autoTriggerBluetoothEnabled = false
            vehicle.syncLegacyConnectionFields()
            didChange = true
            if settings.activeAutoTriggerVehicleID == vehicle.id {
                settings.activeAutoTriggerVehicleID = nil
                settings.clearPairedVehicle()
            }
        }

        if settings.pairedBluetoothChannelEnabled && !settings.pairedCarPlayChannelEnabled {
            settings.activeAutoTriggerVehicleID = nil
            settings.clearPairedVehicle()
            didChange = true
        } else if settings.pairedBluetoothChannelEnabled {
            settings.pairedBluetoothChannelEnabled = false
            if let activeID = settings.activeAutoTriggerVehicleID,
               let vehicle = vehicles.first(where: { $0.id == activeID }) {
                vehicle.autoTriggerBluetoothEnabled = false
                vehicle.syncLegacyConnectionFields()
                mirrorVehicleToSettings(vehicle, settings: settings)
            }
            didChange = true
        }

        if didChange {
            try? context.save()
            reloadConnectionMonitoring()
        }
    }

    static func mergeDuplicateCarPlayProfiles(in context: ModelContext, settings: AppSettings = .shared) {
        let vehicles = fetchVehicles(in: context)
        let duplicates = vehicles.filter { vehicle in
            vehicle.name.caseInsensitiveCompare("CarPlay") == .orderedSame
                || vehicle.connectionDisplayName?.caseInsensitiveCompare("CarPlay") == .orderedSame
        }
        guard duplicates.count > 1 else { return }

        let primary = duplicates.first(where: { $0.id == settings.activeAutoTriggerVehicleID })
            ?? duplicates.first(where: { $0.hasAutoTriggerConnection })
            ?? duplicates.first!

        for duplicate in duplicates where duplicate.id != primary.id {
            if duplicate.autoTriggerCarPlayEnabled { primary.autoTriggerCarPlayEnabled = true }
            if duplicate.autoTriggerBluetoothEnabled {
                primary.autoTriggerBluetoothEnabled = true
                primary.bluetoothTriggerIdentifier = duplicate.bluetoothTriggerIdentifier
                    ?? duplicate.connectionIdentifier
                    ?? duplicate.bluetoothID
                primary.bluetoothTriggerDisplayName = duplicate.bluetoothTriggerDisplayName
                    ?? duplicate.connectionDisplayName
                    ?? duplicate.name
            }
            if primary.name.caseInsensitiveCompare("CarPlay") == .orderedSame,
               let betterName = duplicates.first(where: {
                   $0.name.caseInsensitiveCompare("CarPlay") != .orderedSame
               })?.name {
                primary.name = betterName
            }
            context.delete(duplicate)
        }

        primary.syncLegacyConnectionFields()
        if let activeID = settings.activeAutoTriggerVehicleID,
           duplicates.contains(where: { $0.id == activeID }) {
            settings.activeAutoTriggerVehicleID = primary.id
        }
        try? context.save()
    }

    static func pairChannels(
        vehicle: VehicleProfile,
        carPlay: Bool,
        bluetooth: Bool,
        bluetoothUID: String?,
        bluetoothDisplayName: String?,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        // Auto-start is CarPlay-only. Classic Bluetooth is ignored even if present.
        guard carPlay else {
            AppErrorPresenter.shared.present(L10n.pairingTabWaitingConnection)
            return
        }

        clearAutoTrigger(from: fetchVehicles(in: context), except: vehicle.id)

        vehicle.autoTriggerCarPlayEnabled = true
        vehicle.autoTriggerBluetoothEnabled = false
        vehicle.syncLegacyConnectionFields()

        setDefaultVehicle(vehicle, in: context, save: false)
        settings.activeAutoTriggerVehicleID = vehicle.id
        mirrorVehicleToSettings(vehicle, settings: settings)

        try? context.save()
        VehicleConnectionCoordinator.shared.acknowledgeLiveConnectionWithoutRecording()
        reloadConnectionMonitoring()
    }

    static func pairChannels(
        vehicle: VehicleProfile,
        carPlay: Bool,
        bluetooth: Bool,
        bluetoothIdentifier: String?,
        bluetoothDisplayName: String?,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        pairChannels(
            vehicle: vehicle,
            carPlay: carPlay,
            bluetooth: bluetooth,
            bluetoothUID: bluetoothIdentifier,
            bluetoothDisplayName: bluetoothDisplayName,
            in: context,
            settings: settings
        )
    }

    static func unpair(
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        let vehicles = fetchVehicles(in: context)
        if let activeID = settings.activeAutoTriggerVehicleID,
           let vehicle = vehicles.first(where: { $0.id == activeID }) {
            vehicle.autoTriggerCarPlayEnabled = false
            vehicle.autoTriggerBluetoothEnabled = false
            vehicle.syncLegacyConnectionFields()
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

    private static func fetchVehicles(in context: ModelContext) -> [VehicleProfile] {
        (try? context.fetch(FetchDescriptor<VehicleProfile>())) ?? []
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

    private static func syncVehicleConnection(from settings: AppSettings, to vehicle: VehicleProfile) {
        if settings.pairedCarPlayChannelEnabled || settings.pairedBluetoothChannelEnabled {
            vehicle.autoTriggerCarPlayEnabled = settings.pairedCarPlayChannelEnabled
            vehicle.autoTriggerBluetoothEnabled = settings.pairedBluetoothChannelEnabled
            if settings.pairedBluetoothChannelEnabled {
                vehicle.bluetoothTriggerUID = settings.pairedBluetoothUID
                vehicle.bluetoothTriggerIdentifier = settings.pairedVehicleID
                vehicle.bluetoothTriggerDisplayName = settings.pairedVehicleName
            }
        } else {
            switch settings.pairedVehicleType {
            case .carPlay:
                vehicle.autoTriggerCarPlayEnabled = true
                vehicle.connectionDisplayName = settings.pairedVehicleName ?? "CarPlay"
            case .bluetoothAudio:
                vehicle.autoTriggerBluetoothEnabled = true
                vehicle.bluetoothTriggerUID = settings.pairedBluetoothUID
                vehicle.bluetoothTriggerIdentifier = settings.pairedVehicleID
                vehicle.bluetoothTriggerDisplayName = settings.pairedVehicleName
            case .none:
                break
            }
        }
        vehicle.syncLegacyConnectionFields()
    }

    private static func mirrorVehicleToSettings(_ vehicle: VehicleProfile, settings: AppSettings) {
        settings.activeAutoTriggerVehicleID = vehicle.id
        // Auto-start channel is CarPlay-only; never arm classic Bluetooth.
        settings.pairedCarPlayChannelEnabled = vehicle.autoTriggerCarPlayEnabled
        settings.pairedBluetoothChannelEnabled = false
        settings.pairedBluetoothUID = nil

        if vehicle.autoTriggerCarPlayEnabled {
            settings.pairedVehicleID = VehicleConnectionKind.carPlayVehicleID
            settings.pairedVehicleName = vehicle.connectionDisplayName ?? vehicle.name
            settings.pairedVehicleType = .carPlay
        } else {
            settings.pairedVehicleID = nil
            settings.pairedVehicleName = nil
            settings.pairedVehicleType = nil
        }
    }

    private static func clearAutoTrigger(from vehicles: [VehicleProfile], except keepID: UUID) {
        for vehicle in vehicles where vehicle.id != keepID && vehicle.hasAutoTriggerConnection {
            vehicle.autoTriggerCarPlayEnabled = false
            vehicle.autoTriggerBluetoothEnabled = false
            vehicle.syncLegacyConnectionFields()
        }
    }

    private static func reloadConnectionMonitoring() {
        CarPlayConnectionHandler.shared.refreshConnectionSnapshot()
        AppServices.runtime.bluetoothService.syncRouteSnapshot()
        AppServices.runtime.tripRecordingService.startServices()
    }

    private static func matchesBluetoothVehicle(
        _ vehicle: VehicleProfile,
        pairedID: String,
        settings: AppSettings
    ) -> Bool {
        let identity = settings.bluetoothPairingIdentity
        if let uid = identity.uid, vehicle.bluetoothTriggerUID == uid { return true }
        if vehicle.bluetoothTriggerIdentifier == pairedID { return true }
        if vehicle.bluetoothID == pairedID { return true }
        if vehicle.connectionIdentifier == pairedID { return true }
        if let pairedName = identity.normalizedName,
           let vehicleName = vehicle.bluetoothTriggerDisplayName.map(BluetoothRouteCandidate.normalize),
           pairedName == vehicleName {
            return true
        }
        return false
    }
}

struct LiveVehicleConnection: Equatable {
    let carPlay: Bool
    let bluetoothCandidate: BluetoothRouteCandidate?

    /// Auto-start detection requires CarPlay (scene or `.carAudio`).
    var isDetected: Bool {
        carPlay
    }

    var fingerprint: String {
        var parts: [String] = []
        if carPlay { parts.append("carplay") }
        if let candidate = bluetoothCandidate {
            parts.append(candidate.uid ?? candidate.normalizedName)
        }
        return parts.joined(separator: "|")
    }

    func displayLabel() -> String {
        if carPlay {
            if let candidate = bluetoothCandidate, candidate.portTypeLabel == "CarAudio" {
                return L10n.pairingConnectionCarPlayWired
            }
            return L10n.pairingConnectionCarPlay
        }
        return L10n.pairingLiveConnectionNone
    }
}

extension VehiclePairingService {
    static func detectLiveConnection(bluetoothService: BluetoothTriggerService) -> LiveVehicleConnection {
        LiveVehicleConnection(
            carPlay: PairingConnectionStatus.isCarPlayConnected(bluetoothService: bluetoothService),
            // Kept for diagnostics / `.carAudio` labeling only; not used for auto-start.
            bluetoothCandidate: bluetoothService.connectedCarPlayAudioCandidate()
                ?? bluetoothService.connectedCarCandidate()
        )
    }

    static func confirmLiveConnection(
        vehicle: VehicleProfile,
        live: LiveVehicleConnection,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        guard live.carPlay else {
            AppErrorPresenter.shared.present(L10n.pairingTabWaitingConnection)
            return
        }
        pairChannels(
            vehicle: vehicle,
            carPlay: true,
            bluetooth: false,
            bluetoothUID: nil,
            bluetoothDisplayName: nil,
            in: context,
            settings: settings
        )
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
}
