import CoreLocation
import XCTest
@testable import Trailhound

@MainActor
final class PlaceMatchingServiceTests: XCTestCase {
    func testMatchPlacesAssignsStartAndEndNames() {
        let trip = PreviewData.sampleTrip
        let office = SavedPlace(
            name: "Office",
            latitude: trip.endCoordinate!.latitude,
            longitude: trip.endCoordinate!.longitude,
            radiusMeters: 300
        )
        let home = SavedPlace(
            name: "Home",
            latitude: trip.startCoordinate!.latitude,
            longitude: trip.startCoordinate!.longitude,
            radiusMeters: 300
        )

        PlaceMatchingService.matchPlaces(for: trip, places: [home, office])

        XCTAssertEqual(trip.startPlaceName, "Home")
        XCTAssertEqual(trip.endPlaceName, "Office")
    }

    func testPrivacyDisplayNameWithinRadius() {
        let home = SavedPlace(
            name: "Home",
            latitude: 41.0,
            longitude: 29.0,
            radiusMeters: 200,
            kind: .home,
            isPrivacyZone: true
        )
        let coordinate = CLLocationCoordinate2D(latitude: 41.0005, longitude: 29.0005)

        let displayName = PlaceMatchingService.privacyDisplayName(
            for: coordinate,
            places: [home],
            privacyRadius: 500
        )

        XCTAssertNotNil(displayName)
    }

    func testPrivacyDisplayNameOutsideRadiusReturnsNil() {
        let home = SavedPlace(
            name: "Home",
            latitude: 41.0,
            longitude: 29.0,
            radiusMeters: 100,
            kind: .home,
            isPrivacyZone: true
        )
        let coordinate = CLLocationCoordinate2D(latitude: 42.0, longitude: 30.0)

        let displayName = PlaceMatchingService.privacyDisplayName(
            for: coordinate,
            places: [home],
            privacyRadius: 100
        )

        XCTAssertNil(displayName)
    }

    func testBlurredCoordinateRoundsToTwoDecimals() {
        let blurred = PlaceMatchingService.blurredCoordinate(
            CLLocationCoordinate2D(latitude: 41.00824, longitude: 28.97841)
        )

        XCTAssertEqual(blurred.latitude, 41.01, accuracy: 0.001)
        XCTAssertEqual(blurred.longitude, 28.98, accuracy: 0.001)
    }
}
