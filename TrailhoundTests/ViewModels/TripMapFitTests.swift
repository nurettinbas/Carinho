import CoreLocation
import XCTest
@testable import Trailhound

@MainActor
final class TripMapFitTests: XCTestCase {
    func testPanelInsetZoomsOutMoreThanFullscreen() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            CLLocationCoordinate2D(latitude: 41.004, longitude: 29.006)
        ]

        let fullscreen = TripDetailViewModel.regionFitting(
            coordinates: coordinates,
            fit: .fullscreen
        )
        let withPanel = TripDetailViewModel.regionFitting(
            coordinates: coordinates,
            fit: .detailWithPanel
        )

        XCTAssertNotNil(fullscreen)
        XCTAssertNotNil(withPanel)
        XCTAssertGreaterThan(withPanel!.span.latitudeDelta, fullscreen!.span.latitudeDelta)
    }

    func testShortRouteGetsReadableMinimumZoom() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            CLLocationCoordinate2D(latitude: 41.0004, longitude: 29.0004)
        ]

        let region = TripDetailViewModel.regionFitting(
            coordinates: coordinates,
            fit: .detailWithPanel
        )

        XCTAssertNotNil(region)
        XCTAssertGreaterThanOrEqual(region!.span.latitudeDelta, 0.0016)
    }

    func testLongRouteUsesSmallerRelativeMargin() {
        let coordinates = [
            CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            CLLocationCoordinate2D(latitude: 41.08, longitude: 29.12)
        ]

        let short = TripDetailViewModel.regionFitting(
            coordinates: [
                CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
                CLLocationCoordinate2D(latitude: 41.002, longitude: 29.002)
            ],
            fit: .detailWithPanel
        )
        let long = TripDetailViewModel.regionFitting(
            coordinates: coordinates,
            fit: .detailWithPanel
        )

        XCTAssertNotNil(short)
        XCTAssertNotNil(long)
        let shortMarginRatio = short!.span.latitudeDelta / 0.002
        let longMarginRatio = long!.span.latitudeDelta / 0.08
        XCTAssertLessThan(longMarginRatio, shortMarginRatio)
    }
}
