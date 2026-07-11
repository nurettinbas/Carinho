import Foundation
import SwiftData

@MainActor
enum VehiclePairingService {
    static func migrateLegacyPairingIfNeeded(in context: ModelContext, settings: AppSettings = .shared) {
        mergeDuplicateCarPlayProfiles(in: context, settings: settings)
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
        guard carPlay || bluetooth else {
            AppErrorPresenter.shared.present(L10n.pairingTabMissingConnection)
            return
        }
        if bluetooth, bluetoothDisplayName == nil, bluetoothUID == nil {
            AppErrorPresenter.shared.present(L10n.pairingTabMissingConnection)
            return
        }

        clearAutoTrigger(from: fetchVehicles(in: context), except: vehicle.id)

        vehicle.autoTriggerCarPlayEnabled = carPlay
        vehicle.autoTriggerBluetoothEnabled = bluetooth
        if bluetooth {
            let displayName = bluetoothDisplayName ?? vehicle.name
            let identifier = bluetoothUID
                ?? BluetoothRouteCandidate.normalize(displayName)
            vehicle.bluetoothTriggerUID = bluetoothUID
            vehicle.bluetoothTriggerIdentifier = identifier
            vehicle.bluetoothTriggerDisplayName = displayName
        }
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

    static func pair(
        vehicle: VehicleProfile,
        kind: VehicleConnectionKind,
        identifier: String,
        displayName: String,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        switch kind {
        case .carPlay:
            pairChannels(
                vehicle: vehicle,
                carPlay: true,
                bluetooth: false,
                bluetoothIdentifier: nil,
                bluetoothDisplayName: nil,
                in: context,
                settings: settings
            )
        case .bluetooth:
            pairChannels(
                vehicle: vehicle,
                carPlay: false,
                bluetooth: true,
                bluetoothUID: identifier,
                bluetoothDisplayName: displayName,
                in: context,
                settings: settings
            )
        case .none:
            break
        }
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
        settings.dismissedVehicleIdentityFingerprint = nil
        settings.clearVehicleIdentityPrompt()
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

    static func activeVehicle(in context: ModelContext, settings: AppSettings = .shared) -> VehicleProfile? {
        guard settings.hasAutoTriggerVehicle,
              let activeID = settings.activeAutoTriggerVehicleID else { return nil }
        return fetchVehicles(in: context).first { $0.id == activeID }
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
        settings.pairedCarPlayChannelEnabled = vehicle.autoTriggerCarPlayEnabled
        settings.pairedBluetoothChannelEnabled = vehicle.autoTriggerBluetoothEnabled

        if vehicle.autoTriggerBluetoothEnabled, let identifier = vehicle.bluetoothTriggerIdentifier {
            settings.pairedBluetoothUID = vehicle.bluetoothTriggerUID
            settings.pairedVehicleID = identifier
            settings.pairedVehicleName = vehicle.bluetoothTriggerDisplayName ?? vehicle.name
        } else if vehicle.autoTriggerCarPlayEnabled {
            settings.pairedVehicleID = VehicleConnectionKind.carPlayVehicleID
            settings.pairedVehicleName = vehicle.connectionDisplayName ?? vehicle.name
        }

        if vehicle.autoTriggerCarPlayEnabled && vehicle.autoTriggerBluetoothEnabled {
            settings.pairedVehicleType = .carPlay
        } else if vehicle.autoTriggerCarPlayEnabled {
            settings.pairedVehicleType = .carPlay
        } else if vehicle.autoTriggerBluetoothEnabled {
            settings.pairedVehicleType = .bluetoothAudio
        } else {
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
        VehicleConnectionCoordinator.shared.reloadConfiguration()
        AppServices.runtime.bluetoothService.syncRouteSnapshot()
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

    var isDetected: Bool {
        carPlay || bluetoothCandidate != nil
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
        var parts: [String] = []
        if carPlay {
            parts.append(L10n.pairingConnectionCarPlay)
        }
        if let candidate = bluetoothCandidate {
            parts.append(L10n.pairingConnectionBluetooth(candidate.name, candidate.portTypeLabel))
        }
        return parts.joined(separator: " · ")
    }
}

extension VehiclePairingService {
    static func detectLiveConnection(bluetoothService: BluetoothTriggerService) -> LiveVehicleConnection {
        LiveVehicleConnection(
            carPlay: PairingConnectionStatus.isCarPlayConnected(),
            bluetoothCandidate: bluetoothService.connectedCarCandidate()
        )
    }

    static func confirmLiveConnection(
        vehicle: VehicleProfile,
        live: LiveVehicleConnection,
        in context: ModelContext,
        settings: AppSettings = .shared
    ) {
        guard live.isDetected else {
            AppErrorPresenter.shared.present(L10n.pairingTabWaitingConnection)
            return
        }
        pairChannels(
            vehicle: vehicle,
            carPlay: live.carPlay,
            bluetooth: live.bluetoothCandidate != nil,
            bluetoothUID: live.bluetoothCandidate?.uid,
            bluetoothDisplayName: live.bluetoothCandidate?.name,
            in: context,
            settings: settings
        )
        settings.dismissedVehicleIdentityFingerprint = nil
        settings.clearVehicleIdentityPrompt()
    }

    static func evaluateVehicleIdentityPrompt(
        in context: ModelContext,
        bluetoothService: BluetoothTriggerService,
        preferredVehicleID: UUID? = nil,
        settings: AppSettings = .shared
    ) {
        let live = detectLiveConnection(bluetoothService: bluetoothService)
        guard live.isDetected else {
            settings.clearVehicleIdentityPrompt()
            return
        }

        let vehicles = fetchVehicles(in: context)
        guard !vehicles.isEmpty else { return }

        let vehicle = preferredVehicleID.flatMap { id in vehicles.first(where: { $0.id == id }) }
            ?? vehicles.first(where: \.isDefault)
            ?? vehicles.first!

        if PairingConnectionStatus.isVehicleChannelConnected(
            vehicle: vehicle,
            settings: settings,
            bluetoothService: bluetoothService
        ) {
            settings.clearVehicleIdentityPrompt()
            return
        }

        if settings.dismissedVehicleIdentityFingerprint == live.fingerprint {
            return
        }

        settings.vehicleIdentityConfirmationVehicleID = vehicle.id
        settings.vehicleIdentityConfirmationConnectionLabel = live.displayLabel()
        settings.awaitingVehicleIdentityConfirmation = true
    }

    static func dismissVehicleIdentityPrompt(
        live: LiveVehicleConnection?,
        settings: AppSettings = .shared
    ) {
        settings.dismissedVehicleIdentityFingerprint = live?.fingerprint
        settings.clearVehicleIdentityPrompt()
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
