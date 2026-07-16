import CoreLocation
import Foundation
import SwiftData

enum PlaceMatchingService {
    static func matchPlaces(for trip: Trip, places: [SavedPlace]) {
        guard let start = trip.startCoordinate else { return }
        guard let end = trip.endCoordinate else { return }

        if let startPlace = places.first(where: { $0.contains(start) }) {
            trip.startPlaceName = startPlace.name
        }
        if let endPlace = places.first(where: { $0.contains(end) }) {
            trip.endPlaceName = endPlace.name
        }
    }

    static func privacyDisplayName(
        for coordinate: CLLocationCoordinate2D,
        places: [SavedPlace],
        privacyRadius: Double
    ) -> String? {
        for place in places where place.isPrivacyZone || place.kind == .home {
            let center = CLLocation(latitude: place.latitude, longitude: place.longitude)
            let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let radius = max(place.radiusMeters, privacyRadius)
            if center.distance(from: target) <= radius {
                return "\(place.name) yakını"
            }
        }
        return nil
    }

    static func blurredCoordinate(_ coordinate: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (coordinate.latitude * 100).rounded() / 100,
            longitude: (coordinate.longitude * 100).rounded() / 100
        )
    }
}
