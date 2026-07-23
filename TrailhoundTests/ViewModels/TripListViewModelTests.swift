import CoreLocation
import XCTest
@testable import Trailhound

final class TripListViewModelTests: XCTestCase {
    func testRouteSummaryUsesPlaceNames() {
        let trip = Trip(
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            distanceMeters: 1200,
            startPlaceName: "Home",
            endPlaceName: "Office"
        )

        let summary = TripListViewModel.routeSummary(for: trip)

        XCTAssertTrue(summary.contains("Home"))
        XCTAssertTrue(summary.contains("Office"))
    }

    func testRouteSummaryAppliesPrivacyDisplayName() {
        let home = SavedPlace(
            name: "Home",
            latitude: 41.0082,
            longitude: 28.9784,
            radiusMeters: 500,
            kind: .home,
            isPrivacyZone: true
        )
        let trip = Trip(
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            distanceMeters: 1200,
            startPlaceName: "Exact Home",
            endPlaceName: "Office"
        )
        trip.points = [
            TripPoint(timestamp: trip.startedAt, latitude: 41.0082, longitude: 28.9784, sequence: 0, trip: trip),
            TripPoint(timestamp: trip.endedAt!, latitude: 41.05, longitude: 29.0, sequence: 1, trip: trip)
        ]

        let summary = TripListViewModel.routeSummary(for: trip, places: [home], privacyRadius: 500)

        XCTAssertFalse(summary.contains("Exact Home"))
        XCTAssertTrue(summary.contains("Office") || summary.contains("→"))
    }

    func testMatchesSearchByLabel() {
        let trip = Trip(
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            distanceMeters: 1000,
            label: "Commute"
        )

        XCTAssertTrue(TripListViewModel.matchesSearch(trip, searchText: "comm"))
        XCTAssertFalse(TripListViewModel.matchesSearch(trip, searchText: "holiday"))
    }

    func testMatchesSearchEmptyQueryMatchesAll() {
        let trip = Trip(startedAt: Date(), endedAt: Date(), distanceMeters: 100)

        XCTAssertTrue(TripListViewModel.matchesSearch(trip, searchText: ""))
        XCTAssertTrue(TripListViewModel.matchesSearch(trip, searchText: "   "))
    }

    func testDurationAndDistanceTextForCompletedTrip() {
        let startedAt = Date().addingTimeInterval(-3900)
        let endedAt = Date()
        let trip = Trip(startedAt: startedAt, endedAt: endedAt, distanceMeters: 12_400)

        XCTAssertFalse(TripListViewModel.durationText(for: trip).isEmpty)
        XCTAssertFalse(TripListViewModel.distanceText(for: trip).isEmpty)
        XCTAssertNotNil(TripListViewModel.fuelText(for: trip))
    }
}
