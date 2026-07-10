import Charts
import CoreLocation
import MapKit
import SwiftUI

struct SpeedColoredSegment: Identifiable {
    let id: Int
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
}

@MainActor
struct TripDetailViewModel {
    let trip: Trip
    let places: [SavedPlace]
    let privacyRadius: Double

    private static var speedSegmentCache: [UUID: (pointCount: Int, segments: [SpeedColoredSegment])] = [:]

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

    var speedSamples: [(id: Int, date: Date, speedKmh: Double)] {
        trip.sortedPoints.enumerated().compactMap { index, point in
            guard let speedMps = point.speedMps, speedMps > 0 else { return nil }
            return (id: index, date: point.timestamp, speedKmh: speedMps * 3.6)
        }
    }

    var speedChartMaxKmh: Double {
        let peak = speedSamples.map(\.speedKmh).max() ?? 0
        let reference = max(peak, (trip.maxSpeedMps ?? 0) * 3.6, 60)
        return min(max(reference * 1.15, 80), 200)
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
        let pointCount = trip.sortedPoints.count
        if let cached = Self.speedSegmentCache[trip.id], cached.pointCount == pointCount {
            return cached.segments
        }

        let segments = buildSpeedColoredSegments()
        Self.speedSegmentCache[trip.id] = (pointCount, segments)
        return segments
    }

    private func buildSpeedColoredSegments() -> [SpeedColoredSegment] {
        let points = trip.sortedPoints
        guard points.count >= 2 else { return [] }

        var segments: [SpeedColoredSegment] = []
        var currentCoordinates = [points[0].coordinate]
        var currentColor = Self.speedColor(for: points[0].speedMps)

        for index in 1..<points.count {
            let point = points[index]
            let color = Self.speedColor(for: point.speedMps)

            currentCoordinates.append(point.coordinate)

            if color != currentColor {
                if currentCoordinates.count >= 2 {
                    segments.append(
                        SpeedColoredSegment(
                            id: segments.count,
                            coordinates: currentCoordinates,
                            color: currentColor
                        )
                    )
                }
                currentCoordinates = [points[index - 1].coordinate, point.coordinate]
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
}
