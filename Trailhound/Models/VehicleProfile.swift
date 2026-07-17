import Foundation
import SwiftData

@Model
final class VehicleProfile {
    var id: UUID
    var name: String
    var fuelTypeRaw: String
    var consumption: Double
    var chargePricePerKWh: Double?
    var isDefault: Bool

    /// Auto-start binding: when enabled, the paired Bluetooth audio route
    /// (identified by `pairedRouteUID`) triggers connect-start / disconnect-stop.
    var autoStartEnabled: Bool
    var pairedRouteUID: String?
    var pairedRouteName: String?

    @Relationship(deleteRule: .nullify, inverse: \Trip.vehicle)
    var trips: [Trip]

    init(
        id: UUID = UUID(),
        name: String,
        fuelType: VehicleFuelType = .petrol,
        consumption: Double = 7.5,
        chargePricePerKWh: Double? = nil,
        isDefault: Bool = false,
        autoStartEnabled: Bool = false,
        pairedRouteUID: String? = nil,
        pairedRouteName: String? = nil,
        trips: [Trip] = []
    ) {
        self.id = id
        self.name = name
        self.fuelTypeRaw = fuelType.rawValue
        self.consumption = consumption
        self.chargePricePerKWh = chargePricePerKWh
        self.isDefault = isDefault
        self.autoStartEnabled = autoStartEnabled
        self.pairedRouteUID = pairedRouteUID
        self.pairedRouteName = pairedRouteName
        self.trips = trips
    }

    var fuelType: VehicleFuelType {
        get { VehicleFuelType(rawValue: fuelTypeRaw) ?? .petrol }
        set { fuelTypeRaw = newValue.rawValue }
    }

    var consumptionLabel: String {
        fuelType == .electric ? "kWh/100 km" : "L/100 km"
    }
}
