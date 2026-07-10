import Charts
import CoreLocation
import MapKit
import SwiftUI

struct SpeedColoredSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

struct TripDetailViewModel {
    let trip: Trip
    let places: [SavedPlace]
    let privacyRadius: Double

    var durationText: String {
        guard let duration = trip.duration else { return "—" }
        return DateFormatters.formatDuration(duration)
    }

    var distanceText: String {
        DateFormatters.formatDistance(trip.distanceMeters)
    }

    var dateText: String {
        DateFormatters.tripDate.string(from: trip.startedAt)
    }

    var routeSummary: String {
        TripListViewModel.routeSummary(for: trip, places: places, privacyRadius: privacyRadius)
    }

    var coordinates: [CLLocationCoordinate2D] {
        RoutePrivacyClipper.clip(
            trip.coordinates,
            privacyRadiusMeters: privacyRadius,
            places: places
        )
    }

    var speedSamples: [(date: Date, speedKmh: Double)] {
        trip.sortedPoints.compactMap { point in
            guard let speed = point.speedMps, speed > 0 else { return nil }
            return (date: point.timestamp, speedKmh: speed * 3.6)
        }
    }

    var maxSpeedText: String? {
        guard let maxSpeed = trip.maxSpeedMps, maxSpeed > 0 else { return nil }
        return L10n.formatSpeedKmh(maxSpeed * 3.6)
    }

    var fuelText: String? {
        let cost = StatsViewModel.fuelCost(for: trip)
        guard cost > 0 else { return nil }
        return FuelCostCalculator.formatCost(cost)
    }

    var summaryItems: [(icon: String, title: String, value: String)] {
        var items: [(icon: String, title: String, value: String)] = [
            ("clock", L10n.duration, durationText),
            ("road.lanes", L10n.carPlayDistanceTitle, distanceText)
        ]
        if let maxSpeedText {
            items.append(("speedometer", L10n.maxSpeed, maxSpeedText))
        }
        if let fuelText {
            items.append(("fuelpump", L10n.estimatedFuel, fuelText))
        }
        return items
    }

    var speedColoredSegments: [SpeedColoredSegment] {
        let points = trip.sortedPoints
        guard points.count >= 2 else { return [] }

        var segments: [SpeedColoredSegment] = []
        var currentCoordinates = [points[0].coordinate]
        var currentColor = speedColor(for: points[0].speedMps)

        for index in 1..<points.count {
            let point = points[index]
            let color = speedColor(for: point.speedMps)

            if color == currentColor {
                currentCoordinates.append(point.coordinate)
            } else {
                currentCoordinates.append(point.coordinate)
                if currentCoordinates.count >= 2 {
                    segments.append(
                        SpeedColoredSegment(
                            id: segments.count,
                            coordinates: currentCoordinates,
                            color: currentColor
                        )
                    )
                }
                currentCoordinates = [point.coordinate]
                currentColor = color
            }
        }

        if currentCoordinates.count >= 2 {
            segments.append(
                SpeedColoredSegment(
                    id: segments.count,
                    coordinates: currentCoordinates,
                    color: currentColor
                )
            )
        }

        return segments
    }

    var mapRegion: MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coordinate in coordinates {
            minLat = min(minLat, coordinate.latitude)
            maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude)
            maxLon = max(maxLon, coordinate.longitude)
        }

        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    static func speedColor(for speedMps: Double?) -> Color {
        let kmh = (speedMps ?? 0) * 3.6
        if kmh < 50 { return .green }
        if kmh < 90 { return .yellow }
        return .red
    }

    private func speedColor(for speedMps: Double?) -> Color {
        Self.speedColor(for: speedMps)
    }
}
