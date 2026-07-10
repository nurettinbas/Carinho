import CoreLocation
import Foundation
import SwiftData

enum MockTripSeeder {
    @MainActor
    static func insertSampleTrip(into context: ModelContext) {
        let startedAt = Calendar.current.date(byAdding: .minute, value: -95, to: Date()) ?? Date()
        let endedAt = startedAt.addingTimeInterval(28 * 60)

        // Demo rotası: kara yolu (Gaziemir → Çiğli → Mavişehir), körfez üzerinden düz çizgi değil.
        let routeCoordinates: [CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 38.3197, longitude: 27.1294),
            CLLocationCoordinate2D(latitude: 38.3225, longitude: 27.1265),
            CLLocationCoordinate2D(latitude: 38.3260, longitude: 27.1220),
            CLLocationCoordinate2D(latitude: 38.3295, longitude: 27.1170),
            CLLocationCoordinate2D(latitude: 38.3330, longitude: 27.1110),
            CLLocationCoordinate2D(latitude: 38.3365, longitude: 27.1045),
            CLLocationCoordinate2D(latitude: 38.3400, longitude: 27.0980),
            CLLocationCoordinate2D(latitude: 38.3440, longitude: 27.0920),
            CLLocationCoordinate2D(latitude: 38.3485, longitude: 27.0870),
            CLLocationCoordinate2D(latitude: 38.3535, longitude: 27.0830),
            CLLocationCoordinate2D(latitude: 38.3590, longitude: 27.0800),
            CLLocationCoordinate2D(latitude: 38.3650, longitude: 27.0780),
            CLLocationCoordinate2D(latitude: 38.3720, longitude: 27.0770),
            CLLocationCoordinate2D(latitude: 38.3800, longitude: 27.0762),
            CLLocationCoordinate2D(latitude: 38.3880, longitude: 27.0758),
            CLLocationCoordinate2D(latitude: 38.3960, longitude: 27.0755),
            CLLocationCoordinate2D(latitude: 38.4040, longitude: 27.0752),
            CLLocationCoordinate2D(latitude: 38.4120, longitude: 27.0750),
            CLLocationCoordinate2D(latitude: 38.4200, longitude: 27.0749),
            CLLocationCoordinate2D(latitude: 38.4280, longitude: 27.0748),
            CLLocationCoordinate2D(latitude: 38.4360, longitude: 27.0748),
            CLLocationCoordinate2D(latitude: 38.4440, longitude: 27.0748),
            CLLocationCoordinate2D(latitude: 38.4520, longitude: 27.0749),
            CLLocationCoordinate2D(latitude: 38.4600, longitude: 27.0750),
            CLLocationCoordinate2D(latitude: 38.4670, longitude: 27.0749),
            CLLocationCoordinate2D(latitude: 38.47361, longitude: 27.07472),
        ]

        let locations = routeCoordinates.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        let distanceMeters = DistanceCalculator.totalDistance(for: locations)
        let fuelCost = FuelCostCalculator.estimateCost(distanceMeters: distanceMeters)

        let trip = Trip(
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            startAddress: "Optimum AVM, Gaziemir, İzmir",
            endAddress: "Mavibahçe AVM, Mavişehir, Karşıyaka, İzmir",
            label: "Market",
            category: .personal,
            geocodeStatus: .complete,
            maxSpeedMps: 25,
            estimatedFuelCost: fuelCost,
            isRouteMatched: false,
            startPlaceName: "Optimum AVM",
            endPlaceName: "Mavibahçe"
        )

        context.insert(trip)

        let duration = endedAt.timeIntervalSince(startedAt)
        for (index, coordinate) in routeCoordinates.enumerated() {
            let fraction = Double(index) / Double(max(routeCoordinates.count - 1, 1))
            let timestamp = startedAt.addingTimeInterval(duration * fraction)
            let point = TripPoint(
                timestamp: timestamp,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                sequence: index,
                speedMps: 12 + Double(index),
                trip: trip
            )
            trip.points.append(point)
            context.insert(point)
        }

        try? context.save()
    }

    @MainActor
    static func seedIfEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Trip>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let hasCompletedTrip = existing.contains { $0.endedAt != nil }
        guard !hasCompletedTrip else { return }
        insertSampleTrip(into: context)
    }
}
