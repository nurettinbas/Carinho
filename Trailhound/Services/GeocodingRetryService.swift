import CoreLocation
import Foundation
import SwiftData

@MainActor
@Observable
final class GeocodingRetryService {
    private let geocodingService: GeocodingService
    private let networkMonitor: NetworkMonitor

    init(geocodingService: GeocodingService, networkMonitor: NetworkMonitor = .shared) {
        self.geocodingService = geocodingService
        self.networkMonitor = networkMonitor
    }

    func retryPendingTrips(in context: ModelContext) async {
        guard networkMonitor.isConnected else { return }

        let complete = GeocodeStatus.complete.rawValue
        let trips = TripStore.completed(from: context)

        for trip in trips where trip.geocodeStatusRaw != complete {
            await enrich(trip: trip, context: context)
        }
    }

    private func enrich(trip: Trip, context: ModelContext) async {
        var success = true

        if let startCoordinate = trip.startCoordinate {
            let location = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
            let address = await geocodingService.reverseGeocode(location)
            trip.startAddress = address
            if address == nil { success = false }
        }

        if let endCoordinate = trip.endCoordinate {
            let location = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
            let address = await geocodingService.reverseGeocode(location)
            trip.endAddress = address
            if address == nil { success = false }
        }

        trip.geocodeStatus = success ? .complete : .failed
        try? context.save()
    }
}
