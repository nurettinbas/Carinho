import CoreLocation
import SwiftData
import XCTest
@testable import Trailhound

@MainActor
final class VehicleConnectionCoordinatorTests: XCTestCase {
    func testRepeatedConnectedSnapshotDoesNotDuplicatePersistedState() {
        let defaults = UserDefaults(suiteName: "group.com.trailhound.app") ?? .standard
        defaults.set(true, forKey: "vehicle.lastConnected")
        defaults.set(VehicleConnectionTrigger.bluetooth.rawValue, forKey: "vehicle.lastTrigger")

        let settings = AppSettings.shared
        settings.activeAutoTriggerVehicleID = UUID()
        settings.pairVehicle(uid: "bt-uid", name: "Şair")

        let coordinator = VehicleConnectionCoordinator.shared
        coordinator.handleVehicleSnapshot(isConnected: true)
        coordinator.handleVehicleSnapshot(isConnected: true)

        XCTAssertTrue(defaults.bool(forKey: "vehicle.lastConnected"))
    }

    func testAcknowledgeLiveConnectionPreventsDuplicateConnectScheduling() async throws {
        let shared = AppSettings.shared
        shared.clearPairedVehicle()
        shared.activeAutoTriggerVehicleID = UUID()
        shared.pairVehicle(uid: "bt-uid", name: "Ford Puma")
        let group = UserDefaults(suiteName: "group.com.trailhound.app")!
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
        coordinator.resetSessionStateForTesting()
        coordinator.configure(
            recordingService: recordingService,
            bluetoothService: BluetoothTriggerService(settings: shared)
        )
        coordinator.handleVehicleSnapshot(isConnected: true)

        coordinator.acknowledgeLiveConnectionWithoutRecording()
        coordinator.handleVehicleSnapshot(isConnected: true)

        XCTAssertTrue(group.bool(forKey: "vehicle.lastConnected"))
        XCTAssertEqual(recordingService.state, .idle)

        try? await Task.sleep(for: .seconds(2.5))
        XCTAssertEqual(recordingService.state, .idle)
    }

    func testDisconnectDuringGraceStillEndsTripAfterGraceElapses() async throws {
        let priorGrace = VehicleConnectionCoordinator.testDisconnectGraceSeconds
        let priorPoll = VehicleConnectionCoordinator.testDisconnectPollSeconds
        let priorCount = VehicleConnectionCoordinator.testDisconnectPollCount
        VehicleConnectionCoordinator.testDisconnectGraceSeconds = 1
        VehicleConnectionCoordinator.testDisconnectPollSeconds = 0.2
        VehicleConnectionCoordinator.testDisconnectPollCount = 2
        defer {
            VehicleConnectionCoordinator.testDisconnectGraceSeconds = priorGrace
            VehicleConnectionCoordinator.testDisconnectPollSeconds = priorPoll
            VehicleConnectionCoordinator.testDisconnectPollCount = priorCount
        }

        let shared = AppSettings.shared
        shared.clearPairedVehicle()
        shared.activeAutoTriggerVehicleID = UUID()
        shared.pairVehicle(uid: "bt-uid", name: "Ford Puma")
        let group = UserDefaults(suiteName: "group.com.trailhound.app")!
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
        coordinator.resetSessionStateForTesting()
        coordinator.configure(
            recordingService: recordingService,
            bluetoothService: BluetoothTriggerService(settings: shared)
        )

        coordinator.handleVehicleSnapshot(isConnected: true)
        try await AsyncTestHelpers.waitFor { recordingService.state == .recording }

        coordinator.handleVehicleSnapshot(isConnected: false)
        try await AsyncTestHelpers.waitFor { recordingService.state == .idle }
    }
}

@MainActor
final class VehiclePairingServiceTests: XCTestCase {
    func testPairArmsAutoStartForRoute() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.pairing.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        let candidate = BluetoothRouteCandidate(uid: "puma-bt-hfp", name: "Ford Puma", portTypeLabel: "HFP")
        VehiclePairingService.pair(
            vehicle: vehicle,
            candidate: candidate,
            in: context,
            settings: settings
        )

        XCTAssertEqual(settings.activeAutoTriggerVehicleID, vehicle.id)
        XCTAssertEqual(settings.pairedRouteUID, "puma-bt-hfp")
        XCTAssertEqual(settings.pairedVehicleName, "Ford Puma")
        XCTAssertTrue(settings.hasAutoTriggerVehicle)
        XCTAssertTrue(vehicle.autoStartEnabled)
        XCTAssertEqual(vehicle.pairedRouteUID, "puma-bt-hfp")
    }

    func testPairingSecondVehicleClearsFirst() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.pairing.swap.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let first = VehicleProfile(name: "First")
        let second = VehicleProfile(name: "Second")
        context.insert(first)
        context.insert(second)

        VehiclePairingService.pair(
            vehicle: first,
            candidate: BluetoothRouteCandidate(uid: "first-uid", name: "First", portTypeLabel: "A2DP"),
            in: context,
            settings: settings
        )
        VehiclePairingService.pair(
            vehicle: second,
            candidate: BluetoothRouteCandidate(uid: "second-uid", name: "Second", portTypeLabel: "A2DP"),
            in: context,
            settings: settings
        )

        XCTAssertFalse(first.autoStartEnabled)
        XCTAssertNil(first.pairedRouteUID)
        XCTAssertTrue(second.autoStartEnabled)
        XCTAssertEqual(settings.activeAutoTriggerVehicleID, second.id)
        XCTAssertEqual(settings.pairedRouteUID, "second-uid")
    }

    func testConfirmLiveConnectionRejectsWhenNoRoute() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.confirm.none.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        let live = LiveVehicleConnection(candidate: nil)
        XCTAssertFalse(live.isDetected)

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: context,
            settings: settings
        )

        XCTAssertFalse(settings.hasAutoTriggerVehicle)
        XCTAssertFalse(vehicle.autoStartEnabled)
    }

    func testConfirmLiveConnectionArmsMatchedRoute() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.confirm.bt.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma", consumption: 6.5)
        context.insert(vehicle)

        let candidate = BluetoothRouteCandidate(uid: "puma-uid-123", name: "Ford Puma", portTypeLabel: "HFP")
        let live = LiveVehicleConnection(candidate: candidate)
        XCTAssertTrue(live.isDetected)

        VehiclePairingService.confirmLiveConnection(
            vehicle: vehicle,
            live: live,
            in: context,
            settings: settings
        )

        XCTAssertTrue(settings.hasAutoTriggerVehicle)
        XCTAssertEqual(settings.pairedRouteUID, "puma-uid-123")
        XCTAssertTrue(vehicle.autoStartEnabled)
    }

    func testDeleteVehicleUnpairsActiveProfile() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.delete.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma")
        context.insert(vehicle)
        VehiclePairingService.pair(
            vehicle: vehicle,
            candidate: BluetoothRouteCandidate(uid: "puma-uid", name: "Ford Puma", portTypeLabel: "A2DP"),
            in: context,
            settings: settings
        )

        VehiclePairingService.deleteVehicle(vehicle, in: context, settings: settings)

        let remaining = try context.fetch(FetchDescriptor<VehicleProfile>())
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertNil(settings.activeAutoTriggerVehicleID)
        XCTAssertFalse(settings.hasAutoTriggerVehicle)
    }

    func testUnpairClearsAutoStart() throws {
        let container = try ModelContainer(
            for: Schema(versionedSchema: TrailhoundSchemaV7.self),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let defaults = UserDefaults(suiteName: "test.trailhound.unpair.\(UUID().uuidString)")!
        let settings = AppSettings(userDefaults: defaults)
        let vehicle = VehicleProfile(name: "Ford Puma")
        context.insert(vehicle)
        VehiclePairingService.pair(
            vehicle: vehicle,
            candidate: BluetoothRouteCandidate(uid: "puma-uid", name: "Ford Puma", portTypeLabel: "A2DP"),
            in: context,
            settings: settings
        )

        VehiclePairingService.unpair(in: context, settings: settings)

        XCTAssertFalse(vehicle.autoStartEnabled)
        XCTAssertNil(vehicle.pairedRouteUID)
        XCTAssertNil(settings.activeAutoTriggerVehicleID)
        XCTAssertFalse(settings.hasAutoTriggerVehicle)
    }
}
