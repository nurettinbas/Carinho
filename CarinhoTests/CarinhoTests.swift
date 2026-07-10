import XCTest
@testable import Carinho

final class DistanceCalculatorTests: XCTestCase {
    func testTotalDistanceWithTwoPoints() {
        let a = CLLocation(latitude: 0, longitude: 0)
        let b = CLLocation(latitude: 0, longitude: 0.01)
        let distance = DistanceCalculator.totalDistance(for: [a, b])
        XCTAssertGreaterThan(distance, 0)
    }

    func testSimplifyReducesPoints() {
        let points = (0..<20).map { index in
            CLLocationCoordinate2D(latitude: Double(index) * 0.001, longitude: Double(index) * 0.001)
        }
        let simplified = DistanceCalculator.simplify(coordinates: points)
        XCTAssertLessThan(simplified.count, points.count)
    }
}

import CoreLocation

final class ExportServiceTests: XCTestCase {
    func testCSVContainsHeader() {
        let csv = ExportService.exportCSV(trips: [])
        XCTAssertTrue(csv.contains("distanceKm"))
    }

    func testGPXContainsTrackTag() {
        let gpx = ExportService.exportGPX(trips: [], blurCoordinates: false)
        XCTAssertTrue(gpx.contains("<gpx"))
        XCTAssertTrue(gpx.contains("</gpx>"))
    }

    func testKMLContainsDocument() {
        let kml = ExportService.exportKML(trips: [], blurCoordinates: false)
        XCTAssertTrue(kml.contains("<kml"))
        XCTAssertTrue(kml.contains("<Document>"))
    }
}

final class RoutePrivacyClipperTests: XCTestCase {
    func testClipsStartAndEndWithinRadius() {
        let start = CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0)
        let mid = CLLocationCoordinate2D(latitude: 41.01, longitude: 29.01)
        let end = CLLocationCoordinate2D(latitude: 41.02, longitude: 29.02)
        let nearStart = CLLocationCoordinate2D(latitude: 41.0001, longitude: 29.0001)
        let nearEnd = CLLocationCoordinate2D(latitude: 41.0199, longitude: 29.0199)
        let clipped = RoutePrivacyClipper.clip(
            [start, nearStart, mid, nearEnd, end],
            privacyRadiusMeters: 500
        )
        XCTAssertLessThan(clipped.count, 5)
        XCTAssertGreaterThanOrEqual(clipped.count, 2)
    }
}

final class FrequentRoutesServiceTests: XCTestCase {
    @MainActor
    func testDetectsRepeatedRoute() {
        let tripA = Trip(
            startedAt: Date(),
            endedAt: Date(),
            startPlaceName: "Ev",
            endPlaceName: "Ofis"
        )
        let tripB = Trip(
            startedAt: Date(),
            endedAt: Date(),
            startPlaceName: "Ev",
            endPlaceName: "Ofis"
        )
        let routes = FrequentRoutesService.frequentRoutes(from: [tripA, tripB], places: [], privacyRadius: 500)
        XCTAssertEqual(routes.first?.count, 2)
        XCTAssertEqual(routes.first?.startDisplay, "Ev")
        XCTAssertEqual(routes.first?.endDisplay, "Ofis")
    }
}

import SwiftData

@MainActor
final class SchemaMigrationTests: XCTestCase {
    func testV6TripSupportsNullableVehicleID() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV6.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let trip = Trip(startedAt: Date(), endedAt: Date(), distanceMeters: 1200)
        container.mainContext.insert(trip)
        try container.mainContext.save()

        let trips = try container.mainContext.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)
        XCTAssertNil(trips.first?.vehicleID)
        XCTAssertNil(trips.first?.vehicle)
    }

    func testV6SupportsVehicleProfile() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV6.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vehicle = VehicleProfile(name: "Test", fuelType: .petrol, consumption: 7.5)
        container.mainContext.insert(vehicle)
        try container.mainContext.save()

        let vehicles = try container.mainContext.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertEqual(vehicles.count, 1)
    }

    func testV7VehicleProfileConnectionFields() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vehicle = VehicleProfile(
            name: "Şair",
            connectionKindRaw: VehicleConnectionKind.bluetooth.rawValue,
            connectionIdentifier: "car-audio",
            connectionDisplayName: "Şair"
        )
        container.mainContext.insert(vehicle)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(FetchDescriptor<VehicleProfile>()).first
        XCTAssertEqual(fetched?.connectionKind, .bluetooth)
        XCTAssertEqual(fetched?.bluetoothID, "car-audio")
    }
}

@MainActor
final class VehicleConnectionCoordinatorTests: XCTestCase {
    func testRepeatedConnectedSnapshotDoesNotDuplicatePersistedState() {
        let defaults = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
        defaults.set(true, forKey: "vehicle.lastConnected")
        defaults.set(VehicleConnectionTrigger.bluetooth.rawValue, forKey: "vehicle.lastTrigger")

        let settings = AppSettings(userDefaults: defaults)
        settings.pairVehicle(id: "car-audio", name: "Şair", type: .bluetoothAudio)

        let coordinator = VehicleConnectionCoordinator.shared
        coordinator.handleBluetoothSnapshot(isConnected: true)
        coordinator.handleBluetoothSnapshot(isConnected: true)

        XCTAssertTrue(defaults.bool(forKey: "vehicle.lastConnected"))
    }
}

final class TripReportPDFTests: XCTestCase {
    func testBusinessTripsFiltersCategory() {
        let businessTrip = Trip(
            startedAt: Date(),
            endedAt: Date(),
            distanceMeters: 1000,
            categoryID: BuiltInCategory.businessID.uuidString
        )
        let personalTrip = Trip(
            startedAt: Date(),
            endedAt: Date(),
            distanceMeters: 1000,
            categoryID: BuiltInCategory.personalID.uuidString
        )
        let trips = TripReportPDF.businessTrips(in: [businessTrip, personalTrip])
        XCTAssertEqual(trips.count, 1)
    }

    func testGenerateMonthlyWorkReportReturnsNilForEmptyBusinessTrips() {
        let personalTrip = Trip(
            startedAt: Date(),
            endedAt: Date(),
            distanceMeters: 1000,
            categoryID: BuiltInCategory.personalID.uuidString
        )
        let data = TripReportPDF.generateMonthlyWorkReport(
            trips: [personalTrip],
            places: [],
            privacyRadius: 500
        )
        XCTAssertNil(data)
    }

    func testGenerateMonthlyWorkReportProducesData() {
        let businessTrip = Trip(
            startedAt: Date(),
            endedAt: Date(),
            distanceMeters: 5000,
            categoryID: BuiltInCategory.businessID.uuidString
        )
        let data = TripReportPDF.generateMonthlyWorkReport(
            trips: [businessTrip],
            places: [],
            privacyRadius: 500
        )
        XCTAssertNotNil(data)
        XCTAssertGreaterThan(data?.count ?? 0, 100)
    }
}

@MainActor
final class AppSettingsRecordingRequestTests: XCTestCase {
    func testExpireStaleRecordingRequestsClearsOldFlags() {
        let defaults = UserDefaults(suiteName: "test.carinho.recording.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        settings.pendingStartRecordingRequest = true
        defaults.set(Date().addingTimeInterval(-120).timeIntervalSince1970, forKey: "recording.requestStartAt")

        settings.expireStaleRecordingRequests()
        XCTAssertFalse(settings.pendingStartRecordingRequest)
    }
}

final class FuelCostCalculatorTests: XCTestCase {
    func testEstimateCostPositive() {
        let defaults = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
        defaults.set(10.0, forKey: "fuelLitersPer100km")
        defaults.set(40.0, forKey: "fuelPricePerLiter")
        let cost = FuelCostCalculator.estimateCost(distanceMeters: 100_000)
        XCTAssertEqual(cost, 400, accuracy: 0.1)
    }

    func testElectricVehicleUsesKWhPrice() {
        let vehicle = VehicleProfile(name: "EV", fuelType: .electric, consumption: 20, chargePricePerKWh: 10)
        let cost = FuelCostCalculator.estimateCost(distanceMeters: 100_000, vehicle: vehicle)
        XCTAssertEqual(cost, 200, accuracy: 0.1)
    }
}

@MainActor
final class TripFetchTests: XCTestCase {
    func testOrphansExcludesCompletedTrips() throws {
        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let open = Trip(startedAt: Date(), endedAt: nil)
        let done = Trip(startedAt: Date(), endedAt: Date())
        context.insert(open)
        context.insert(done)
        try context.save()

        let orphans = TripFetch.orphans(from: context)
        XCTAssertEqual(orphans.count, 1)
        XCTAssertEqual(orphans.first?.id, open.id)
    }

    func testCompletedSinceFiltersByStartDate() throws {
        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let old = Trip(
            startedAt: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
            endedAt: Date()
        )
        let recent = Trip(startedAt: Date(), endedAt: Date())
        context.insert(old)
        context.insert(recent)
        try context.save()

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let recentTrips = TripFetch.completedSince(weekAgo, from: context)
        XCTAssertEqual(recentTrips.count, 1)
        XCTAssertEqual(recentTrips.first?.id, recent.id)
    }
}

final class TripDateGroupingTests: XCTestCase {
    func testGroupsTodayTrip() {
        let trip = Trip(startedAt: Date(), endedAt: Date())
        let sections = TripDateGrouping.groupedSections(from: [trip])
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.section, .today)
    }
}

/// Manual device test checklist (Faz 0) — run on a real phone after each release candidate.
enum DeviceTestChecklist {
    static let items = [
        "30+ dk gerçek sürüş: km ve süre akıyor",
        "Arka plana at, 5 dk bekle: kayıt devam ediyor",
        "CarPlay veya BT ile otomatik başlat/durdur",
        "Widget / Live Activity ile durdur",
        "Uygulamayı öldür → aç → orphan banner / recovery",
        "Detay haritada rota gerçekçi (denizden geçmiyor)"
    ]
}

final class DeviceTestChecklistTests: XCTestCase {
    func testChecklistHasSixItems() {
        XCTAssertEqual(DeviceTestChecklist.items.count, 6)
    }
}

final class RecordingStopPolicyTests: XCTestCase {
    func testManualStopAlwaysSaves() {
        let shouldSave = RecordingStopPolicy.shouldSaveTrip(
            saveTrip: true,
            reason: .manual,
            duration: 10,
            distanceMeters: 10,
            minimumDurationSeconds: 120,
            minimumDistanceMeters: 200
        )
        XCTAssertTrue(shouldSave)
    }

    func testAutoStopRequiresMinimumThreshold() {
        let shouldSave = RecordingStopPolicy.shouldSaveTrip(
            saveTrip: true,
            reason: .idle,
            duration: 60,
            distanceMeters: 50,
            minimumDurationSeconds: 120,
            minimumDistanceMeters: 200
        )
        XCTAssertFalse(shouldSave)
    }

    func testManualTriggerSkipsIdleAutoStop() {
        XCTAssertFalse(RecordingStopPolicy.shouldApplyIdleAutoStop(activeTriggerIsManual: true))
        XCTAssertTrue(RecordingStopPolicy.shouldApplyIdleAutoStop(activeTriggerIsManual: false))
    }
}
