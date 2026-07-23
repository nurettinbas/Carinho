import SwiftData
import XCTest
@testable import Trailhound

@MainActor
final class TripMergeServiceTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainerFactory.makeInMemory()
    }

    func testMergeReturnsNilForSingleTrip() throws {
        let trip = makeTrip(
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            distanceMeters: 1000
        )
        container.mainContext.insert(trip)
        try container.mainContext.save()

        let merged = try TripMergeService.merge(trips: [trip], into: container.mainContext)

        XCTAssertNil(merged)
    }

    func testMergeCombinesDistanceDurationAndNotes() throws {
        let first = makeTrip(
            startedAt: Date().addingTimeInterval(-7200),
            endedAt: Date().addingTimeInterval(-5400),
            distanceMeters: 3000,
            note: "First leg",
            label: "Morning"
        )
        let second = makeTrip(
            startedAt: Date().addingTimeInterval(-3600),
            endedAt: Date(),
            distanceMeters: 4500,
            note: "Second leg",
            label: "Evening"
        )
        container.mainContext.insert(first)
        container.mainContext.insert(second)
        try container.mainContext.save()

        let expectedPointCount = first.points.count + second.points.count
        let merged = try XCTUnwrap(
            TripMergeService.merge(trips: [first, second], into: container.mainContext)
        )

        XCTAssertEqual(merged.distanceMeters, 7500, accuracy: 0.1)
        XCTAssertEqual(merged.startedAt, first.startedAt)
        XCTAssertEqual(merged.endedAt, second.endedAt)
        XCTAssertEqual(merged.points.count, expectedPointCount)
        XCTAssertTrue(merged.note?.contains("First leg") == true)
        XCTAssertTrue(merged.note?.contains("Second leg") == true)
        XCTAssertTrue(merged.label?.contains("Morning") == true)
        XCTAssertTrue(merged.label?.contains("Evening") == true)
    }

    private func makeTrip(
        startedAt: Date,
        endedAt: Date,
        distanceMeters: Double,
        note: String? = nil,
        label: String? = nil
    ) -> Trip {
        let trip = Trip(
            startedAt: startedAt,
            endedAt: endedAt,
            distanceMeters: distanceMeters,
            note: note,
            label: label,
            category: .personal
        )
        let start = TripPoint(
            timestamp: startedAt,
            latitude: 41.0,
            longitude: 29.0,
            sequence: 0,
            trip: trip
        )
        let end = TripPoint(
            timestamp: endedAt,
            latitude: 41.01,
            longitude: 29.01,
            sequence: 1,
            trip: trip
        )
        trip.points = [start, end]
        return trip
    }
}
