import Foundation
import SwiftData

@Model
final class VehicleProfile {
    var id: UUID
    var name: String
    var fuelTypeRaw: String
    var consumption: Double
    var bluetoothID: String?
    var carPlayFlag: Bool
    var chargePricePerKWh: Double?
    var isDefault: Bool
    var connectionKindRaw: String?
    var connectionIdentifier: String?
    var connectionDisplayName: String?
    var autoTriggerCarPlayEnabled: Bool
    var autoTriggerBluetoothEnabled: Bool
    var bluetoothTriggerIdentifier: String?
    var bluetoothTriggerDisplayName: String?
    var bluetoothTriggerUID: String?

    @Relationship(deleteRule: .nullify, inverse: \Trip.vehicle)
    var trips: [Trip]

    init(
        id: UUID = UUID(),
        name: String,
        fuelType: VehicleFuelType = .petrol,
        consumption: Double = 7.5,
        bluetoothID: String? = nil,
        carPlayFlag: Bool = false,
        chargePricePerKWh: Double? = nil,
        isDefault: Bool = false,
        connectionKindRaw: String? = nil,
        connectionIdentifier: String? = nil,
        connectionDisplayName: String? = nil,
        autoTriggerCarPlayEnabled: Bool = false,
        autoTriggerBluetoothEnabled: Bool = false,
        bluetoothTriggerIdentifier: String? = nil,
        bluetoothTriggerDisplayName: String? = nil,
        bluetoothTriggerUID: String? = nil,
        trips: [Trip] = []
    ) {
        self.id = id
        self.name = name
        self.fuelTypeRaw = fuelType.rawValue
        self.consumption = consumption
        self.bluetoothID = bluetoothID
        self.carPlayFlag = carPlayFlag
        self.chargePricePerKWh = chargePricePerKWh
        self.isDefault = isDefault
        self.connectionKindRaw = connectionKindRaw
        self.connectionIdentifier = connectionIdentifier
        self.connectionDisplayName = connectionDisplayName
        self.autoTriggerCarPlayEnabled = autoTriggerCarPlayEnabled
        self.autoTriggerBluetoothEnabled = autoTriggerBluetoothEnabled
        self.bluetoothTriggerIdentifier = bluetoothTriggerIdentifier
        self.bluetoothTriggerDisplayName = bluetoothTriggerDisplayName
        self.bluetoothTriggerUID = bluetoothTriggerUID
        self.trips = trips
    }

    var fuelType: VehicleFuelType {
        get { VehicleFuelType(rawValue: fuelTypeRaw) ?? .petrol }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var connectionKind: VehicleConnectionKind {
        get {
            if autoTriggerCarPlayEnabled && autoTriggerBluetoothEnabled {
                return .carPlay
            }
            if autoTriggerCarPlayEnabled { return .carPlay }
            if autoTriggerBluetoothEnabled { return .bluetooth }
            if let raw = connectionKindRaw, let kind = VehicleConnectionKind(rawValue: raw) {
                return kind
            }
            if carPlayFlag { return .carPlay }
            if bluetoothID != nil { return .bluetooth }
            return .none
        }
        set {
            autoTriggerCarPlayEnabled = newValue == .carPlay
            autoTriggerBluetoothEnabled = newValue == .bluetooth
            connectionKindRaw = newValue == .none ? nil : newValue.rawValue
            syncLegacyConnectionFields()
        }
    }

    var hasAutoTriggerConnection: Bool {
        (autoTriggerCarPlayEnabled || autoTriggerBluetoothEnabled)
            && (autoTriggerCarPlayEnabled || bluetoothTriggerIdentifier != nil)
    }

    var consumptionLabel: String {
        fuelType == .electric ? "kWh/100 km" : "L/100 km"
    }

    func migrateLegacyTriggerFlagsIfNeeded() {
        guard !autoTriggerCarPlayEnabled, !autoTriggerBluetoothEnabled else {
            migrateBluetoothIdentityIfNeeded()
            return
        }
        if let raw = connectionKindRaw, let kind = VehicleConnectionKind(rawValue: raw) {
            switch kind {
            case .carPlay:
                autoTriggerCarPlayEnabled = true
            case .bluetooth:
                autoTriggerBluetoothEnabled = true
                if bluetoothTriggerIdentifier == nil {
                    bluetoothTriggerIdentifier = connectionIdentifier ?? bluetoothID
                    bluetoothTriggerDisplayName = connectionDisplayName ?? name
                }
            case .none:
                break
            }
        } else if carPlayFlag {
            autoTriggerCarPlayEnabled = true
        } else if let bluetoothID {
            autoTriggerBluetoothEnabled = true
            bluetoothTriggerIdentifier = bluetoothID
            bluetoothTriggerDisplayName = connectionDisplayName ?? name
        }
        migrateBluetoothIdentityIfNeeded()
    }

    func migrateBluetoothIdentityIfNeeded() {
        guard autoTriggerBluetoothEnabled else { return }
        guard bluetoothTriggerUID == nil, let identifier = bluetoothTriggerIdentifier else { return }
        let normalizedDisplay = BluetoothRouteCandidate.normalize(bluetoothTriggerDisplayName ?? name)
        if identifier != normalizedDisplay {
            bluetoothTriggerUID = identifier
        }
    }

    func syncLegacyConnectionFields() {
        if autoTriggerBluetoothEnabled {
            if bluetoothTriggerUID == nil, let identifier = bluetoothTriggerIdentifier {
                let normalizedDisplay = BluetoothRouteCandidate.normalize(bluetoothTriggerDisplayName ?? name)
                if identifier != normalizedDisplay {
                    bluetoothTriggerUID = identifier
                }
            }
            if bluetoothTriggerIdentifier == nil {
                bluetoothTriggerIdentifier = bluetoothTriggerUID
                    ?? bluetoothID
                    ?? connectionIdentifier
                    ?? bluetoothTriggerDisplayName.map(BluetoothRouteCandidate.normalize)
            }
            bluetoothID = bluetoothTriggerIdentifier ?? connectionIdentifier
            if bluetoothTriggerDisplayName == nil {
                bluetoothTriggerDisplayName = connectionDisplayName ?? name
            }
            connectionIdentifier = bluetoothTriggerIdentifier
            connectionDisplayName = bluetoothTriggerDisplayName
            connectionKindRaw = VehicleConnectionKind.bluetooth.rawValue
            carPlayFlag = autoTriggerCarPlayEnabled
        } else if autoTriggerCarPlayEnabled {
            carPlayFlag = true
            connectionKindRaw = VehicleConnectionKind.carPlay.rawValue
            connectionIdentifier = VehicleConnectionKind.carPlayVehicleID
            if connectionDisplayName == nil {
                connectionDisplayName = name
            }
            if !autoTriggerBluetoothEnabled {
                bluetoothID = nil
                bluetoothTriggerIdentifier = nil
                bluetoothTriggerDisplayName = nil
                bluetoothTriggerUID = nil
            }
        } else {
            bluetoothID = nil
            carPlayFlag = false
            connectionIdentifier = nil
            connectionDisplayName = nil
            connectionKindRaw = nil
            bluetoothTriggerIdentifier = nil
            bluetoothTriggerDisplayName = nil
            bluetoothTriggerUID = nil
        }
    }

    func channelSummaryText(carPlayLabel: String, bluetoothLabel: String) -> String {
        var channels: [String] = []
        if autoTriggerCarPlayEnabled { channels.append(carPlayLabel) }
        if autoTriggerBluetoothEnabled { channels.append(bluetoothLabel) }
        return channels.joined(separator: " + ")
    }
}
