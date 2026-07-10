import CoreLocation
import Foundation

enum RoutePrivacyClipper {
    static func clip(
        _ coordinates: [CLLocationCoordinate2D],
        privacyRadiusMeters: Double,
        places: [SavedPlace] = []
    ) -> [CLLocationCoordinate2D] {
        guard coordinates.count >= 2 else { return coordinates }
        guard let routeStart = coordinates.first, let routeEnd = coordinates.last else { return coordinates }

        let startRadius = effectiveRadius(for: routeStart, places: places, defaultRadius: privacyRadiusMeters)
        let endRadius = effectiveRadius(for: routeEnd, places: places, defaultRadius: privacyRadiusMeters)

        var trimmed = coordinates

        while trimmed.count > 2, let first = trimmed.first {
            let distance = CLLocation(latitude: first.latitude, longitude: first.longitude)
                .distance(from: CLLocation(latitude: routeStart.latitude, longitude: routeStart.longitude))
            if distance <= startRadius {
                trimmed.removeFirst()
            } else {
                break
            }
        }

        while trimmed.count > 2, let last = trimmed.last {
            let distance = CLLocation(latitude: last.latitude, longitude: last.longitude)
                .distance(from: CLLocation(latitude: routeEnd.latitude, longitude: routeEnd.longitude))
            if distance <= endRadius {
                trimmed.removeLast()
            } else {
                break
            }
        }

        return trimmed.count >= 2 ? trimmed : coordinates
    }

    private static func effectiveRadius(
        for coordinate: CLLocationCoordinate2D,
        places: [SavedPlace],
        defaultRadius: Double
    ) -> Double {
        var radius = defaultRadius
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        for place in places where place.isPrivacyZone || place.kind == .home {
            let center = CLLocation(latitude: place.latitude, longitude: place.longitude)
            if center.distance(from: target) <= max(place.radiusMeters, defaultRadius) {
                radius = max(radius, place.radiusMeters, defaultRadius)
            }
        }
        return radius
    }
}
