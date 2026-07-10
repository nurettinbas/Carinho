import Foundation

enum VehicleConnectionKind: String, Codable, CaseIterable {
    case bluetooth
    case carPlay
    case none

    /// Stable identifier for CarPlay pairing (not a real Bluetooth address).
    static let carPlayVehicleID = "carinho.carplay"
}
