import XCTest

final class TrailhoundUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-UITesting"]
        app.launchEnvironment["AppleLanguages"] = "(en)"
        app.launchEnvironment["AppleLocale"] = "en_US"
        app.launch()
    }

    private var tripsTab: XCUIElement {
        app.tabBars.buttons["Trips"]
    }

    private var statsTab: XCUIElement {
        app.tabBars.buttons["Statistics"]
    }

    private var settingsTab: XCUIElement {
        app.tabBars.buttons["Settings"]
    }

    private var pairingTab: XCUIElement {
        app.tabBars.buttons["Pairing"]
    }

    func testAppLaunchesToTripsTab() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))
    }

    func testTabNavigationTripsStatsSettingsPairing() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))

        statsTab.tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))

        settingsTab.tap()
        XCTAssertTrue(app.switches["settings.recordingSounds"].waitForExistence(timeout: 5))

        pairingTab.tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))

        tripsTab.tap()
        XCTAssertTrue(tripsTab.exists)
    }

    func testTripListOpensDetail() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))

        let firstTrip = app.buttons["trips.row.first"]
        XCTAssertTrue(firstTrip.waitForExistence(timeout: 15))
        firstTrip.tap()

        XCTAssertTrue(app.otherElements["tripDetail.screen"].waitForExistence(timeout: 10))
    }

    func testSettingsRecordingSoundsToggle() {
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 15))
        settingsTab.tap()
        let toggle = app.switches["settings.recordingSounds"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 10))
        XCTAssertTrue(toggle.isEnabled)
    }

    func testNotificationsListOpens() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))

        let notifications = app.buttons["trips.notifications"]
        XCTAssertTrue(notifications.waitForExistence(timeout: 10))
        notifications.tap()

        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 10))
    }

    func testTripDetailSaveButtonExists() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["trips.row.first"].waitForExistence(timeout: 15))
        app.buttons["trips.row.first"].tap()

        XCTAssertTrue(app.buttons["tripDetail.save"].waitForExistence(timeout: 10))
    }

    func testTripDetailScrollRevealsSaveButton() {
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["trips.row.first"].waitForExistence(timeout: 15))
        app.buttons["trips.row.first"].tap()
        XCTAssertTrue(app.otherElements["tripDetail.screen"].waitForExistence(timeout: 10))

        let saveButton = app.buttons["tripDetail.save"]
        if !saveButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
    }

    func testStatsTabShowsContent() {
        XCTAssertTrue(statsTab.waitForExistence(timeout: 15))
        statsTab.tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 10))
    }
}
