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
        self.trips = trips
        syncLegacyConnectionFields()
    }

    var fuelType: VehicleFuelType {
        get { VehicleFuelType(rawValue: fuelTypeRaw) ?? .petrol }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var connectionKind: VehicleConnectionKind {
        get {
            if let raw = connectionKindRaw, let kind = VehicleConnectionKind(rawValue: raw) {
                return kind
            }
            if carPlayFlag { return .carPlay }
            if bluetoothID != nil { return .bluetooth }
            return .none
        }
        set {
            connectionKindRaw = newValue == .none ? nil : newValue.rawValue
            syncLegacyConnectionFields()
        }
    }

    var hasAutoTriggerConnection: Bool {
        connectionKind != .none && connectionIdentifier != nil
    }

    var consumptionLabel: String {
        fuelType == .electric ? "kWh/100 km" : "L/100 km"
    }

    func syncLegacyConnectionFields() {
        switch connectionKind {
        case .bluetooth:
            bluetoothID = connectionIdentifier
            carPlayFlag = false
        case .carPlay:
            bluetoothID = nil
            carPlayFlag = true
            if connectionIdentifier == nil {
                connectionIdentifier = AppSettings.carPlayVehicleID
            }
            if connectionDisplayName == nil {
                connectionDisplayName = "CarPlay"
            }
        case .none:
            bluetoothID = nil
            carPlayFlag = false
            connectionIdentifier = nil
            connectionDisplayName = nil
            connectionKindRaw = nil
        }
    }
}
