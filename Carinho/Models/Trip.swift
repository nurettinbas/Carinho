import Foundation
import SwiftData
import CoreLocation

@Model
final class Trip {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var startAddress: String?
    var endAddress: String?
    var note: String?
    var label: String?
    var categoryRaw: String
    var geocodeStatusRaw: String
    var maxSpeedMps: Double?
    var estimatedFuelCost: Double?
    var isRouteMatched: Bool
    var matchedDistanceMeters: Double?
    var startPlaceName: String?
    var endPlaceName: String?
    var vehicleID: UUID?
    @Relationship(deleteRule: .nullify)
    var vehicle: VehicleProfile?
    @Relationship(deleteRule: .cascade, inverse: \TripPoint.trip)
    var points: [TripPoint]
    @Relationship(deleteRule: .cascade, inverse: \TripStop.trip)
    var stops: [TripStop]
    @Relationship(deleteRule: .cascade, inverse: \MatchedRoutePoint.trip)
    var matchedPoints: [MatchedRoutePoint]

    @Transient private var sortedPointsCache: [TripPoint]?
    @Transient private var sortedMatchedPointsCache: [MatchedRoutePoint]?

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        distanceMeters: Double = 0,
        startAddress: String? = nil,
        endAddress: String? = nil,
        note: String? = nil,
        label: String? = nil,
        category: TripCategory = .personal,
        geocodeStatus: GeocodeStatus = .pending,
        maxSpeedMps: Double? = nil,
        estimatedFuelCost: Double? = nil,
        isRouteMatched: Bool = false,
        matchedDistanceMeters: Double? = nil,
        startPlaceName: String? = nil,
        endPlaceName: String? = nil,
        vehicleID: UUID? = nil,
        vehicle: VehicleProfile? = nil,
        points: [TripPoint] = [],
        stops: [TripStop] = [],
        matchedPoints: [MatchedRoutePoint] = []
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.distanceMeters = distanceMeters
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.note = note
        self.label = label
        self.categoryRaw = category.rawValue
        self.geocodeStatusRaw = geocodeStatus.rawValue
        self.maxSpeedMps = maxSpeedMps
        self.estimatedFuelCost = estimatedFuelCost
        self.isRouteMatched = isRouteMatched
        self.matchedDistanceMeters = matchedDistanceMeters
        self.startPlaceName = startPlaceName
        self.endPlaceName = endPlaceName
        self.vehicleID = vehicleID
        self.vehicle = vehicle
        self.points = points
        self.stops = stops
        self.matchedPoints = matchedPoints
    }

    func invalidatePointCaches() {
        sortedPointsCache = nil
        sortedMatchedPointsCache = nil
    }

    var category: TripCategory {
        get { TripCategory(rawValue: categoryRaw) ?? .personal }
        set { categoryRaw = newValue.rawValue }
    }

    var categoryID: String {
        get {
            if let legacy = TripCategory(rawValue: categoryRaw) {
                switch legacy {
                case .personal: return BuiltInCategory.personalID.uuidString
                case .business: return BuiltInCategory.businessID.uuidString
                }
            }
            return categoryRaw
        }
        set { categoryRaw = newValue }
    }

    var geocodeStatus: GeocodeStatus {
        get { GeocodeStatus(rawValue: geocodeStatusRaw) ?? .pending }
        set { geocodeStatusRaw = newValue.rawValue }
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var sortedPoints: [TripPoint] {
        if let sortedPointsCache { return sortedPointsCache }
        let sorted = points.sorted { $0.sequence < $1.sequence }
        sortedPointsCache = sorted
        return sorted
    }

    var sortedMatchedPoints: [MatchedRoutePoint] {
        if let sortedMatchedPointsCache { return sortedMatchedPointsCache }
        let sorted = matchedPoints.sorted { $0.sequence < $1.sequence }
        sortedMatchedPointsCache = sorted
        return sorted
    }

    var coordinates: [CLLocationCoordinate2D] {
        sortedPoints.map(\.coordinate)
    }

    var startCoordinate: CLLocationCoordinate2D? {
        sortedPoints.first?.coordinate
    }

    var endCoordinate: CLLocationCoordinate2D? {
        sortedPoints.last?.coordinate
    }

    var displayStartName: String {
        if let startPlaceName { return startPlaceName }
        if let startAddress, !startAddress.isEmpty { return startAddress }
        if let startCoordinate { return DateFormatters.formatCoordinate(startCoordinate) }
        return "Başlangıç"
    }

    var displayEndName: String {
        if let endPlaceName { return endPlaceName }
        if let endAddress, !endAddress.isEmpty { return endAddress }
        if let endCoordinate { return DateFormatters.formatCoordinate(endCoordinate) }
        return "Bitiş"
    }
}
