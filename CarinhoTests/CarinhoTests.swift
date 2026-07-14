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
        vehicle.migrateLegacyTriggerFlagsIfNeeded()
        vehicle.syncLegacyConnectionFields()
        container.mainContext.insert(vehicle)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(FetchDescriptor<VehicleProfile>()).first
        XCTAssertEqual(fetched?.connectionKind, .bluetooth)
        XCTAssertEqual(fetched?.bluetoothID, "car-audio")
    }

    func testV7VehicleProfileMultiChannelFields() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let vehicle = VehicleProfile(
            name: "Ford Puma",
            autoTriggerCarPlayEnabled: true,
            autoTriggerBluetoothEnabled: true,
            bluetoothTriggerIdentifier: "puma-bt",
            bluetoothTriggerDisplayName: "Ford Puma"
        )
        container.mainContext.insert(vehicle)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(FetchDescriptor<VehicleProfile>()).first
        XCTAssertTrue(fetched?.autoTriggerCarPlayEnabled == true)
        XCTAssertTrue(fetched?.autoTriggerBluetoothEnabled == true)
        XCTAssertEqual(fetched?.bluetoothTriggerIdentifier, "puma-bt")
    }
}

@MainActor
final class VehicleConnectionCoordinatorTests: XCTestCase {
    func testRepeatedConnectedSnapshotDoesNotDuplicatePersistedState() {
        let defaults = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
        defaults.set(true, forKey: "vehicle.lastConnected")
        defaults.set(VehicleConnectionTrigger.bluetooth.rawValue, forKey: "vehicle.lastTrigger")

        let settings = AppSettings(userDefaults: defaults)
        settings.activeAutoTriggerVehicleID = UUID()
        settings.pairVehicle(id: "car-audio", name: "Şair", type: .bluetoothAudio)

        let coordinator = VehicleConnectionCoordinator.shared
        coordinator.handleBluetoothSnapshot(isConnected: true)
        coordinator.handleBluetoothSnapshot(isConnected: true)

        XCTAssertTrue(defaults.bool(forKey: "vehicle.lastConnected"))
    }

    func testAcknowledgeLiveConnectionPreventsDuplicateConnectScheduling() async throws {
        // The coordinator reads `AppSettings.shared`, so pairing is configured there.
        let shared = AppSettings.shared
        shared.clearPairedVehicle()
        shared.activeAutoTriggerVehicleID = UUID()
        shared.pairVehicle(id: "car-audio", name: "Ford Puma", type: .bluetoothAudio)
        let group = UserDefaults(suiteName: "group.com.carinho.app")!
        group.removeObject(forKey: "vehicle.lastConnected")
        group.removeObject(forKey: "vehicle.lastTrigger")
        defer {
            shared.clearPairedVehicle()
            shared.activeAutoTriggerVehicleID = nil
            group.removeObject(forKey: "vehicle.lastConnected")
            group.removeObject(forKey: "vehicle.lastTrigger")
        }

        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recordingService = TripRecordingService(
            locationService: LocationService(),
            settings: shared
        )
        recordingService.configure(modelContext: container.mainContext)

        let coordinator = VehicleConnectionCoordinator.shared
        coordinator.configure(
            recordingService: recordingService,
            bluetoothService: BluetoothTriggerService(settings: shared)
        )
        coordinator.handleBluetoothSnapshot(isConnected: true)

        coordinator.acknowledgeLiveConnectionWithoutRecording()
        coordinator.handleBluetoothSnapshot(isConnected: true)

        XCTAssertTrue(group.bool(forKey: "vehicle.lastConnected"))
        XCTAssertEqual(recordingService.state, .idle)

        try? await Task.sleep(for: .seconds(2.5))
        XCTAssertEqual(recordingService.state, .idle)
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
final class TripStoreTests: XCTestCase {
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

        let orphans = TripStore.orphans(from: context)
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
        let recentTrips = TripStore.completedSince(weekAgo, from: context)
        XCTAssertEqual(recentTrips.count, 1)
        XCTAssertEqual(recentTrips.first?.id, recent.id)
    }
}

@MainActor
final class TripRecoveryServiceTests: XCTestCase {
    func testDeleteOrphanSucceedsWhenTripAlreadyEnded() throws {
        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let ended = Trip(startedAt: Date().addingTimeInterval(-120), endedAt: Date())
        context.insert(ended)
        try context.save()

        XCTAssertTrue(TripRecoveryService.deleteOrphan(ended, in: context))
        XCTAssertNotNil(ended.endedAt)
    }

    func testFinalizeOrphanSucceedsWhenTripAlreadyEnded() throws {
        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let endedAt = Date()
        let ended = Trip(startedAt: Date().addingTimeInterval(-120), endedAt: endedAt)
        context.insert(ended)
        try context.save()

        XCTAssertTrue(TripRecoveryService.finalizeOrphan(ended, in: context, saveTrip: true))
        XCTAssertEqual(ended.endedAt, endedAt)
    }

    func testFinalizeOrphanSavesOpenTrip() throws {
        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let open = Trip(startedAt: Date().addingTimeInterval(-120), endedAt: nil)
        context.insert(open)
        try context.save()

        XCTAssertTrue(TripRecoveryService.finalizeOrphan(open, in: context, saveTrip: true))
        XCTAssertNotNil(open.endedAt)
        XCTAssertEqual(TripStore.orphans(from: context).count, 0)
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
            reason: .bluetooth,
            duration: 60,
            distanceMeters: 50,
            minimumDurationSeconds: 120,
            minimumDistanceMeters: 200
        )
        XCTAssertFalse(shouldSave)
    }

    func testAutoStopSavesWhenAboveThreshold() {
        let shouldSave = RecordingStopPolicy.shouldSaveTrip(
            saveTrip: true,
            reason: .bluetooth,
            duration: 300,
            distanceMeters: 5000,
            minimumDurationSeconds: 120,
            minimumDistanceMeters: 200
        )
        XCTAssertTrue(shouldSave)
    }
}

@MainActor
final class VehiclePairingServiceTests: XCTestCase {
    func testPairChannelsEnablesDualAutoTrigger() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.pairing.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        VehiclePairingService.pairChannels(
            vehicle: vehicle,
            carPlay: true,
            bluetooth: true,
            bluetoothUID: "puma-bt-hfp",
            bluetoothDisplayName: "Ford Puma",
            in: context,
            settings: settings
        )

        XCTAssertEqual(settings.activeAutoTriggerVehicleID, vehicle.id)
        XCTAssertTrue(settings.pairedCarPlayChannelEnabled)
        XCTAssertTrue(settings.pairedBluetoothChannelEnabled)
        XCTAssertEqual(settings.pairedBluetoothUID, "puma-bt-hfp")
        XCTAssertEqual(settings.pairedVehicleID, "puma-bt-hfp")
        XCTAssertEqual(vehicle.bluetoothTriggerUID, "puma-bt-hfp")
    }

    func testConfirmLiveConnectionCapturesBluetoothUID() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.confirm.bt.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        let candidate = BluetoothRouteCandidate(uid: "puma-uid-123", name: "Ford Puma", portTypeLabel: "HFP")
        let live = LiveVehicleConnection(carPlay: false, bluetoothCandidate: candidate)

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: context,
            settings: settings
        )

        XCTAssertTrue(settings.pairedBluetoothChannelEnabled)
        XCTAssertFalse(settings.pairedCarPlayChannelEnabled)
        XCTAssertEqual(settings.pairedBluetoothUID, "puma-uid-123")
        XCTAssertEqual(vehicle.bluetoothTriggerUID, "puma-uid-123")
    }

    func testConfirmLiveConnectionCarPlayAudioCapturesUID() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.confirm.cp.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        // Wired/wireless CarPlay surfaces as a `.carAudio` port with a UID.
        let candidate = BluetoothRouteCandidate(uid: "carplay-uid", name: "CarPlay", portTypeLabel: "CarAudio")
        let live = LiveVehicleConnection(carPlay: true, bluetoothCandidate: candidate)

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: context,
            settings: settings
        )

        XCTAssertTrue(settings.pairedCarPlayChannelEnabled)
        XCTAssertTrue(settings.pairedBluetoothChannelEnabled)
        XCTAssertEqual(settings.pairedBluetoothUID, "carplay-uid")
    }

    func testConfirmLiveConnectionSceneOnlyCarPlayEnablesCarPlayOnly() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.confirm.scene.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        // Scene-only wireless CarPlay: no audio route identity available.
        let live = LiveVehicleConnection(carPlay: true, bluetoothCandidate: nil)

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: context,
            settings: settings
        )

        XCTAssertTrue(settings.pairedCarPlayChannelEnabled)
        XCTAssertFalse(settings.pairedBluetoothChannelEnabled)
    }

    func testDeleteVehicleUnpairsActiveProfile() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.delete.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma")
        context.insert(vehicle)
        VehiclePairingService.pairChannels(
            vehicle: vehicle,
            carPlay: true,
            bluetooth: false,
            bluetoothIdentifier: nil,
            bluetoothDisplayName: nil,
            in: context,
            settings: settings
        )

        VehiclePairingService.deleteVehicle(vehicle, in: context, settings: settings)

        let remaining = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertNil(settings.activeAutoTriggerVehicleID)
        XCTAssertFalse(settings.hasAutoTriggerVehicle)
    }

    func testRepairStaleActivePairingClearsMissingVehicle() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let defaults = UserDefaults(suiteName: "test.carinho.stale.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        settings.activeAutoTriggerVehicleID = UUID()
        settings.pairedCarPlayChannelEnabled = true
        settings.pairedVehicleID = VehicleConnectionKind.carPlayVehicleID

        VehiclePairingService.repairStaleActivePairing(in: container.mainContext, settings: settings)

        XCTAssertNil(settings.activeAutoTriggerVehicleID)
        XCTAssertFalse(settings.pairedCarPlayChannelEnabled)
    }

    func testRepairStaleActivePairingClearsOrphanedPairingFlags() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: CarinhoSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.carinho.stale.flags.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(
            name: "Ford",
            autoTriggerCarPlayEnabled: true
        )
        context.insert(vehicle)
        settings.activeAutoTriggerVehicleID = vehicle.id
        settings.pairedCarPlayChannelEnabled = false
        settings.pairedBluetoothChannelEnabled = false

        VehiclePairingService.repairStaleActivePairing(in: context, settings: settings)

        XCTAssertNil(settings.activeAutoTriggerVehicleID)
        XCTAssertFalse(vehicle.autoTriggerCarPlayEnabled)
    }
}

final class BluetoothRouteMatcherTests: XCTestCase {
    func testMatchesByUID() {
        let candidate = BluetoothRouteCandidate(uid: "AA:BB:CC", name: "Ford Puma", portTypeLabel: "HFP")
        let pairing = BluetoothPairingIdentity(uid: "AA:BB:CC", displayName: "Ford Puma", legacyIdentifier: "AA:BB:CC")

        XCTAssertEqual(
            BluetoothRouteMatcher.match(candidate: candidate, pairing: pairing),
            .uid
        )
    }

    func testMatchesByNameWhenUIDChangesBetweenPorts() {
        let candidate = BluetoothRouteCandidate(uid: "AA:BB:DD", name: "Ford Puma", portTypeLabel: "A2DP")
        let pairing = BluetoothPairingIdentity(uid: "AA:BB:CC", displayName: "Ford Puma", legacyIdentifier: "AA:BB:CC")

        XCTAssertEqual(
            BluetoothRouteMatcher.match(candidate: candidate, pairing: pairing),
            .name
        )
    }

    func testMatchesLegacyIdentifierWhenOnlyNameWasStored() {
        let candidate = BluetoothRouteCandidate(uid: "AA:BB:CC", name: "Ford Puma", portTypeLabel: "HFP")
        let pairing = BluetoothPairingIdentity(uid: nil, displayName: "Ford Puma", legacyIdentifier: "ford puma")

        XCTAssertEqual(
            BluetoothRouteMatcher.match(candidate: candidate, pairing: pairing),
            .name
        )
    }

    func testDoesNotMatchUnknownDevice() {
        let candidate = BluetoothRouteCandidate(uid: "UNKNOWN", name: "AirPods Pro", portTypeLabel: "A2DP")
        let pairing = BluetoothPairingIdentity(uid: "AA:BB:CC", displayName: "Ford Puma", legacyIdentifier: "AA:BB:CC")

        XCTAssertNil(
            BluetoothRouteMatcher.match(candidate: candidate, pairing: pairing)
        )
    }
}

@MainActor
final class TabSelectionTests: XCTestCase {
    func testOpenPairingSelectsPairingTab() {
        let tabs = TabSelection.shared
        tabs.selectedTab = .trips
        tabs.openPairing()
        XCTAssertEqual(tabs.selectedTab, .pairing)
    }
}

final class DeviceTestChecklistTests: XCTestCase {
    func testChecklistHasSixItems() {
        XCTAssertEqual(DeviceTestChecklist.items.count, 6)
    }
}

@MainActor
final class VehicleConnectRecordingTests: XCTestCase {
    private func makeService(
        paired: Bool = true
    ) throws -> (TripRecordingService, LocationService, AppSettings, ModelContext) {
        let defaults = UserDefaults(suiteName: "test.carinho.connect.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        if paired {
            settings.activeAutoTriggerVehicleID = UUID()
            settings.pairVehicle(id: "car-audio", name: "Test Car", type: .bluetoothAudio)
        }

        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let locationService = LocationService()
        let recordingService = TripRecordingService(
            locationService: locationService,
            settings: settings
        )
        recordingService.configure(modelContext: context)
        return (recordingService, locationService, settings, context)
    }

    func testBluetoothConnectStartsRecordingImmediately() throws {
        let (recordingService, _, _, context) = try makeService()

        recordingService.handleVehicleConnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .recording)
        XCTAssertNotNil(recordingService.activeTripID)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)
    }

    func testCarPlayConnectStartsRecordingImmediately() throws {
        let (recordingService, _, settings, context) = try makeService(paired: false)
        settings.activeAutoTriggerVehicleID = UUID()
        settings.pairVehicle(id: "carplay", name: "Test Car", type: .carPlay)

        recordingService.handleVehicleConnected(trigger: .carPlay)

        XCTAssertEqual(recordingService.state, .recording)
        XCTAssertNotNil(recordingService.activeTripID)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)
    }

    func testDisconnectStopsRecording() throws {
        let (recordingService, _, _, context) = try makeService()
        recordingService.handleVehicleConnected(trigger: .bluetooth)
        XCTAssertEqual(recordingService.state, .recording)

        recordingService.handleVehicleDisconnected(trigger: .bluetooth)

        // Disconnect stops recording immediately. With no distance/duration the
        // automatic stop is below threshold, so the trip is discarded.
        XCTAssertEqual(recordingService.state, .idle)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertTrue(trips.isEmpty)
    }

    func testDisconnectStopsManuallyStartedRecording() throws {
        let (recordingService, _, _, _) = try makeService()
        _ = recordingService.startManualRecording()
        XCTAssertEqual(recordingService.state, .recording)

        // Leaving the car ends even a manually-started session.
        recordingService.handleVehicleDisconnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .idle)
    }

    func testUnpairedBluetoothConnectDoesNothing() throws {
        let (recordingService, _, _, context) = try makeService(paired: false)

        recordingService.handleVehicleConnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .idle)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertTrue(trips.isEmpty)
    }

    /// The coordinator reads `AppSettings.shared`, so pairing must be configured
    /// there (not on an isolated instance) for these tests to be deterministic.
    private func makeSharedPairedCoordinator() throws -> (TripRecordingService, VehicleConnectionCoordinator, ModelContext) {
        let shared = AppSettings.shared
        shared.clearPairedVehicle()
        shared.activeAutoTriggerVehicleID = UUID()
        shared.pairVehicle(id: "car-audio", name: "Test Car", type: .bluetoothAudio)
        resetCoordinatorPersistedState()

        let container = try ModelContainer(
            for: Trip.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let recordingService = TripRecordingService(
            locationService: LocationService(),
            settings: shared
        )
        recordingService.configure(modelContext: container.mainContext)

        let coordinator = VehicleConnectionCoordinator.shared
        coordinator.configure(
            recordingService: recordingService,
            bluetoothService: BluetoothTriggerService(settings: shared)
        )
        return (recordingService, coordinator, container.mainContext)
    }

    func testManualStopWhileConnectedDoesNotRestartUntilReconnect() async throws {
        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(recordingService.state, .recording)

        recordingService.stopManualRecording()
        XCTAssertEqual(recordingService.state, .idle)

        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(recordingService.state, .idle)

        // A genuine disconnect must clear before a reconnect can restart. The
        // disconnect is confirmed only after the verification window elapses.
        coordinator.handleBluetoothSnapshot(isConnected: false)
        try await Task.sleep(for: .seconds(3.4))
        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(recordingService.state, .recording)
    }

    private func resetCoordinatorPersistedState() {
        let group = UserDefaults(suiteName: "group.com.carinho.app") ?? .standard
        group.removeObject(forKey: "vehicle.lastConnected")
        group.removeObject(forKey: "vehicle.lastTrigger")
    }

    func testMomentaryDisconnectKeepsRecording() async throws {
        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(recordingService.state, .recording)

        // Momentary drop immediately followed by a reconnect within the window.
        coordinator.handleBluetoothSnapshot(isConnected: false)
        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(3.5))
        XCTAssertEqual(recordingService.state, .recording)
    }

    func testSustainedDisconnectStopsRecordingAfterVerification() async throws {
        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleBluetoothSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.2))
        XCTAssertEqual(recordingService.state, .recording)

        // Sustained disconnect: still gone after the verification window, so the
        // session ends. With no distance the below-threshold trip is discarded.
        coordinator.handleBluetoothSnapshot(isConnected: false)
        try await Task.sleep(for: .seconds(3.5))
        XCTAssertEqual(recordingService.state, .idle)
    }

    func testManualStopDuringRecordingAlwaysSavesShortTrip() throws {
        let (recordingService, locationService, _, context) = try makeService()
        recordingService.handleVehicleConnected(trigger: .bluetooth)

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 0,
            speed: 12,
            timestamp: Date()
        )
        locationService.onLocationUpdate?(location)
        XCTAssertEqual(recordingService.state, .recording)

        recordingService.stopManualRecording()

        XCTAssertEqual(recordingService.state, .idle)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)
        XCTAssertNotNil(trips.first?.endedAt)
        XCTAssertEqual(trips.first?.distanceMeters ?? -1, 0, accuracy: 0.1)
    }

    func testRecordingAccumulatesDistanceBetweenNearbyGPSUpdates() async throws {
        let (recordingService, locationService, _, context) = try makeService()
        _ = recordingService.startManualRecording()

        let start = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            altitude: 0,
            horizontalAccuracy: 8,
            verticalAccuracy: 8,
            course: 0,
            speed: 10,
            timestamp: Date()
        )
        let end = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.00004, longitude: 29.00004),
            altitude: 0,
            horizontalAccuracy: 8,
            verticalAccuracy: 8,
            course: 0,
            speed: 10,
            timestamp: Date().addingTimeInterval(4)
        )

        locationService.onLocationUpdate?(start)
        try await Task.sleep(for: .milliseconds(100))
        locationService.onLocationUpdate?(end)
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertGreaterThan(recordingService.currentDistanceMeters, 4)

        recordingService.stopManualRecording()

        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)
        XCTAssertGreaterThan(trips.first?.distanceMeters ?? 0, 4)
        // Points are thinned, so nearby updates accumulate distance without
        // necessarily storing a separate point for each fix.
        XCTAssertGreaterThanOrEqual(trips.first?.points.count ?? 0, 1)
    }

    func testManualStartBeginsRecordingImmediately() async throws {
        let (recordingService, locationService, _, context) = try makeService()
        _ = recordingService.startManualRecording()

        XCTAssertEqual(recordingService.state, .recording)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertEqual(trips.count, 1)

        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 41.0, longitude: 29.0),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 0,
            speed: 12,
            timestamp: Date()
        )
        locationService.onLocationUpdate?(location)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(trips.first?.points.count, 1)
    }
}
