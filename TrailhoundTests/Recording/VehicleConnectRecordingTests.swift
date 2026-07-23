import CoreLocation
import SwiftData
import XCTest
@testable import Trailhound

@MainActor
final class VehicleConnectRecordingTests: XCTestCase {
    private func makeService(
        paired: Bool = true
    ) throws -> (TripRecordingService, LocationService, AppSettings, ModelContext) {
        let defaults = UserDefaults(suiteName: "test.trailhound.connect.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        if paired {
            settings.activeAutoTriggerVehicleID = UUID()
            settings.pairVehicle(uid: "bt-uid", name: "Test Car")
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

    func testUnpairedBluetoothConnectDoesNothing() throws {
        let (recordingService, _, _, context) = try makeService(paired: false)

        recordingService.handleVehicleConnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .idle)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertTrue(trips.isEmpty)
    }

    func testDisconnectStopsRecording() throws {
        let (recordingService, _, _, context) = try makeService()
        recordingService.handleVehicleConnected(trigger: .bluetooth)
        XCTAssertEqual(recordingService.state, .recording)

        recordingService.handleVehicleDisconnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .idle)
        let trips = try context.fetch(FetchDescriptor<Trip>())
        XCTAssertTrue(trips.isEmpty)
    }

    func testDisconnectStopsManuallyStartedRecording() throws {
        let (recordingService, _, _, _) = try makeService()
        _ = recordingService.startManualRecording()
        XCTAssertEqual(recordingService.state, .recording)

        recordingService.handleVehicleDisconnected(trigger: .bluetooth)

        XCTAssertEqual(recordingService.state, .idle)
    }

    private func makeSharedPairedCoordinator() throws -> (TripRecordingService, VehicleConnectionCoordinator, ModelContext) {
        let shared = AppSettings.shared
        shared.clearPairedVehicle()
        shared.activeAutoTriggerVehicleID = UUID()
        shared.pairVehicle(uid: "bt-uid", name: "Test Car")
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
        coordinator.resetSessionStateForTesting()
        coordinator.configure(
            recordingService: recordingService,
            bluetoothService: BluetoothTriggerService(settings: shared)
        )
        return (recordingService, coordinator, container.mainContext)
    }

    private func resetCoordinatorPersistedState() {
        let group = UserDefaults(suiteName: "group.com.trailhound.app") ?? .standard
        group.removeObject(forKey: "vehicle.lastConnected")
        group.removeObject(forKey: "vehicle.lastTrigger")
    }

    func testManualStopWhileConnectedDoesNotRestartUntilReconnect() async throws {
        let priorGrace = VehicleConnectionCoordinator.testDisconnectGraceSeconds
        let priorPoll = VehicleConnectionCoordinator.testDisconnectPollSeconds
        let priorCount = VehicleConnectionCoordinator.testDisconnectPollCount
        VehicleConnectionCoordinator.testDisconnectGraceSeconds = 0.5
        VehicleConnectionCoordinator.testDisconnectPollSeconds = 0.2
        VehicleConnectionCoordinator.testDisconnectPollCount = 2
        defer {
            VehicleConnectionCoordinator.testDisconnectGraceSeconds = priorGrace
            VehicleConnectionCoordinator.testDisconnectPollSeconds = priorPoll
            VehicleConnectionCoordinator.testDisconnectPollCount = priorCount
        }

        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleVehicleSnapshot(isConnected: true)
        try await AsyncTestHelpers.waitFor { recordingService.state == .recording }

        recordingService.stopManualRecording()
        XCTAssertEqual(recordingService.state, .idle)

        coordinator.handleVehicleSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertEqual(recordingService.state, .idle)

        coordinator.handleVehicleSnapshot(isConnected: false)
        try await AsyncTestHelpers.waitFor(timeout: 6) { recordingService.state == .idle }
        coordinator.handleVehicleSnapshot(isConnected: true)
        try await AsyncTestHelpers.waitFor { recordingService.state == .recording }
    }

    func testMomentaryDisconnectKeepsRecording() async throws {
        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleVehicleSnapshot(isConnected: true)
        try await AsyncTestHelpers.waitFor { recordingService.state == .recording }

        coordinator.handleVehicleSnapshot(isConnected: false)
        coordinator.handleVehicleSnapshot(isConnected: true)
        try await Task.sleep(for: .seconds(1.5))
        XCTAssertEqual(recordingService.state, .recording)
    }

    func testSustainedDisconnectStopsRecordingAfterVerification() async throws {
        let priorGrace = VehicleConnectionCoordinator.testDisconnectGraceSeconds
        let priorPoll = VehicleConnectionCoordinator.testDisconnectPollSeconds
        let priorCount = VehicleConnectionCoordinator.testDisconnectPollCount
        VehicleConnectionCoordinator.testDisconnectGraceSeconds = 0.5
        VehicleConnectionCoordinator.testDisconnectPollSeconds = 0.2
        VehicleConnectionCoordinator.testDisconnectPollCount = 2
        defer {
            VehicleConnectionCoordinator.testDisconnectGraceSeconds = priorGrace
            VehicleConnectionCoordinator.testDisconnectPollSeconds = priorPoll
            VehicleConnectionCoordinator.testDisconnectPollCount = priorCount
        }

        let (recordingService, coordinator, _) = try makeSharedPairedCoordinator()

        coordinator.handleVehicleSnapshot(isConnected: true)
        try await AsyncTestHelpers.waitFor { recordingService.state == .recording }

        coordinator.handleVehicleSnapshot(isConnected: false)
        try await AsyncTestHelpers.waitFor { recordingService.state == .idle }
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
