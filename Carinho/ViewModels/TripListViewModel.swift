import Foundation

struct TripListViewModel {
    static func routeSummary(for trip: Trip, places: [SavedPlace] = [], privacyRadius: Double = 500) -> String {
        let start = displayName(
            placeName: trip.startPlaceName,
            address: trip.startAddress,
            coordinate: trip.startCoordinate,
            places: places,
            privacyRadius: privacyRadius
        )
        let end = displayName(
            placeName: trip.endPlaceName,
            address: trip.endAddress,
            coordinate: trip.endCoordinate,
            places: places,
            privacyRadius: privacyRadius
        )
        return "\(start) → \(end)"
    }

    private static func displayName(
        placeName: String?,
        address: String?,
        coordinate: CLLocationCoordinate2D?,
        places: [SavedPlace],
        privacyRadius: Double
    ) -> String {
        if let coordinate,
           let privacy = PlaceMatchingService.privacyDisplayName(for: coordinate, places: places, privacyRadius: privacyRadius) {
            return privacy
        }
        if let placeName { return placeName }
        if let address, !address.isEmpty { return address }
        if let coordinate { return DateFormatters.formatCoordinate(coordinate) }
        return "—"
    }

    static func durationText(for trip: Trip) -> String {
        guard let duration = trip.duration else { return "—" }
        return DateFormatters.formatDuration(duration)
    }

    static func distanceText(for trip: Trip) -> String {
        DateFormatters.formatDistance(trip.distanceMeters)
    }

    static func dateText(for trip: Trip) -> String {
        DateFormatters.formatTripDateRange(startedAt: trip.startedAt, endedAt: trip.endedAt)
    }

    static func fuelText(for trip: Trip) -> String? {
        let cost = StatsViewModel.fuelCost(for: trip)
        guard cost > 0 else { return nil }
        return FuelCostCalculator.formatCost(cost)
    }

    static func maxSpeedText(for trip: Trip) -> String? {
        guard let maxSpeed = trip.maxSpeedMps, maxSpeed > 0 else { return nil }
        return L10n.formatSpeedKmh(maxSpeed * 3.6)
    }

    static func averageSpeedText(for trip: Trip) -> String? {
        guard let duration = trip.duration, duration > 0, trip.distanceMeters > 0 else { return nil }
        let averageKmh = trip.distanceMeters * 3.6 / duration
        guard averageKmh > 0 else { return nil }
        return L10n.formatSpeedKmh(averageKmh)
    }

    static func maxSpeedLabel(for trip: Trip) -> String? {
        guard let speed = maxSpeedText(for: trip) else { return nil }
        return "\(L10n.maxAbbr) \(speed)"
    }

    static func averageSpeedLabel(for trip: Trip) -> String? {
        guard let speed = averageSpeedText(for: trip) else { return nil }
        return "\(L10n.avgAbbr) \(speed)"
    }

    static func matchesSearch(
        _ trip: Trip,
        searchText: String,
        places: [SavedPlace] = [],
        privacyRadius: Double = 500
    ) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        let lowercasedQuery = query.lowercased()
        let candidates = [
            routeSummary(for: trip, places: places, privacyRadius: privacyRadius),
            trip.label,
            trip.note,
            trip.startAddress,
            trip.endAddress,
            trip.startPlaceName,
            trip.endPlaceName
        ]

        return candidates.contains { value in
            guard let value, !value.isEmpty else { return false }
            return value.lowercased().contains(lowercasedQuery)
        }
    }
}

import CoreLocation
