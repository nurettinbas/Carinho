import CoreLocation
import XCTest
@testable import Trailhound

final class SharedUtilityTests: XCTestCase {
    func testFormatDurationOmitsHoursWhenShort() {
        XCTAssertEqual(DateFormatters.formatDuration(125), "2:05")
    }

    func testFormatDurationIncludesHoursWhenNeeded() {
        XCTAssertEqual(DateFormatters.formatDuration(3661), "1:01:01")
    }

    func testFormatCoordinateUsesFourDecimalPlaces() {
        let text = DateFormatters.formatCoordinate(
            CLLocationCoordinate2D(latitude: 41.00824, longitude: 28.97841)
        )
        XCTAssertTrue(text.contains("41.0082"))
        XCTAssertTrue(text.contains("28.9784"))
    }

    func testRecordingControlBridgeSharedDefaultsAccessible() {
        let defaults = RecordingControlBridge.sharedDefaults()
        XCTAssertNotNil(defaults)
        XCTAssertEqual(RecordingControlBridge.appGroupSuiteName, "group.com.trailhound.app")
    }
}
