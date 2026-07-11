import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppRuntime {
    private var location: LocationService?
    private var motion: MotionActivityService?
    private var geocoding: GeocodingService?
    private var geocodingRetry: GeocodingRetryService?
    private var recording: TripRecordingService?
    private var bluetooth: BluetoothTriggerService?
    private var lock: AppLockService?
    private var network: NetworkMonitor?
    private var didRecordingBootstrap = false
    private var didFullBootstrap = false

    init() {}

    var locationService: LocationService {
        if let location { return location }
        let service = LocationService()
        location = service
        return service
    }

    var motionActivityService: MotionActivityService {
        if let motion { return motion }
        let service = MotionActivityService()
        motion = service
        return service
    }

    var geocodingService: GeocodingService {
        if let geocoding { return geocoding }
        let service = GeocodingService()
        geocoding = service
        return service
    }

    var geocodingRetryService: GeocodingRetryService {
        if let geocodingRetry { return geocodingRetry }
        let service = GeocodingRetryService(geocodingService: geocodingService)
        geocodingRetry = service
        return service
    }

    var tripRecordingService: TripRecordingService {
        if let recording { return recording }
        let service = TripRecordingService(
            locationService: locationService,
            geocodingService: geocodingService,
            motionActivityService: motionActivityService
        )
        recording = service
        CarPlayConnectionHandler.shared.tripRecordingService = service
        return service
    }

    var bluetoothService: BluetoothTriggerService {
        if let bluetooth { return bluetooth }
        let service = BluetoothTriggerService()
        bluetooth = service
        return service
    }

    var appLockService: AppLockService {
        if let lock { return lock }
        let service = AppLockService()
        lock = service
        return service
    }

    var networkMonitor: NetworkMonitor {
        if let network { return network }
        let service = NetworkMonitor.shared
        network = service
        return service
    }

    func bootstrapRecording(container: ModelContainer) {
        guard !didRecordingBootstrap else { return }
        didRecordingBootstrap = true

        bluetoothService.activate()
        tripRecordingService.configure(modelContext: container.mainContext)
        VehicleConnectionCoordinator.shared.configure(recordingService: tripRecordingService)
        tripRecordingService.startServices()
        wireVehicleConnectionHandlers(container: container)
        wireRecordingRequestHandlers()
        VehicleConnectionCoordinator.shared.handleCarPlaySnapshot(
            isConnected: CarPlayConnectionHandler.shared.isConnected
        )
        bluetoothService.syncRouteSnapshot()
    }

    func bootstrap(container: ModelContainer) {
        bootstrapRecording(container: container)
        guard !didFullBootstrap else { return }
        didFullBootstrap = true

        networkMonitor.startIfNeeded()
        CategorySeeder.seedIfNeeded(in: container.mainContext)
        VehiclePairingService.seedDefaultVehicleIfNeeded(in: container.mainContext)
        VehiclePairingService.migrateLegacyPairingIfNeeded(in: container.mainContext)
        VehiclePairingService.repairStaleActivePairing(in: container.mainContext)
        TripStore.syncWidgetWeekDistance(in: container.mainContext)
        TripRecoveryService.finalizeStaleOrphans(in: container.mainContext)
        TripRecoveryService.scheduleOrphanStaleNotifications(
            in: container.mainContext,
            excludingTripID: tripRecordingService.activeTripID
        )

        networkMonitor.onConnected = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.geocodingRetryService.retryPendingTrips(in: container.mainContext)
            }
        }

        if AppSettings.shared.autoDeleteDays > 0 {
            _ = try? TripCleanupService.cleanupOldTrips(
                in: container.mainContext,
                olderThanDays: AppSettings.shared.autoDeleteDays
            )
        }
    }

    var shouldKeepVehicleMonitoring: Bool {
        let settings = AppSettings.shared
        return tripRecordingService.state.isActiveSession
            || settings.isPairedBluetoothVehicle
            || settings.isPairedCarPlayVehicle
            || settings.autoRecordingEnabled
    }

    func resumeMonitoringIfNeeded() {
        if shouldKeepVehicleMonitoring {
            tripRecordingService.startServices()
            bluetoothService.syncRouteSnapshot()
        }
    }

    func suspendIdleMonitoringIfNeeded() {
        guard !shouldKeepVehicleMonitoring else { return }
        tripRecordingService.stopIdleServices()
    }

    private func wireVehicleConnectionHandlers(container: ModelContainer) {
        bluetoothService.onRouteSnapshotChanged = { isConnected in
            VehicleConnectionCoordinator.shared.handleBluetoothSnapshot(isConnected: isConnected)
            VehiclePairingService.syncLearnedBluetoothUID(in: container.mainContext)
            VehiclePairingService.evaluateVehicleIdentityPrompt(
                in: container.mainContext,
                bluetoothService: self.bluetoothService
            )
        }
        CarPlayConnectionHandler.shared.onConnectionSnapshotChanged = { isConnected in
            VehicleConnectionCoordinator.shared.handleCarPlaySnapshot(isConnected: isConnected)
            VehiclePairingService.evaluateVehicleIdentityPrompt(
                in: container.mainContext,
                bluetoothService: self.bluetoothService
            )
        }
    }

    private func wireRecordingRequestHandlers() {
        RecordingRequestObserver.shared.onStopRequested = { [weak self] in
            self?.tripRecordingService.processExternalStopRequest()
        }
        RecordingRequestObserver.shared.onStartRequested = { [weak self] in
            self?.tripRecordingService.processExternalStartRequest()
        }
        RecordingRequestObserver.shared.onPauseRequested = { [weak self] in
            self?.tripRecordingService.processExternalPauseRequest()
        }
        RecordingRequestObserver.shared.onResumeRequested = { [weak self] in
            self?.tripRecordingService.processExternalResumeRequest()
        }
        RecordingRequestObserver.shared.install()
    }

    func processPendingRecordingRequests() {
        let settings = AppSettings.shared
        settings.expireStaleRecordingRequests()
        if settings.pendingStopRecordingRequest {
            tripRecordingService.processExternalStopRequest()
            return
        }
        if settings.pendingStartRecordingRequest || settings.awaitingExternalStartConfirmation {
            tripRecordingService.processExternalStartRequest()
            return
        }
        if settings.pendingPauseRecordingRequest {
            tripRecordingService.processExternalPauseRequest()
            return
        }
        if settings.pendingResumeRecordingRequest {
            tripRecordingService.processExternalResumeRequest()
        }
    }
}

@main
struct CarinhoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var didEnterBackground = false

    private var runtime: AppRuntime { AppServices.runtime }
    private var modelContainer: ModelContainer { AppServices.modelContainer }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(modelContainer)
                .environment(runtime.locationService)
                .environment(runtime.motionActivityService)
                .environment(runtime.tripRecordingService)
                .environment(runtime.bluetoothService)
                .environment(runtime.appLockService)
                .environment(runtime.geocodingRetryService)
                .environment(runtime.networkMonitor)
                .task {
                    await Task.yield()
                    runtime.bootstrap(container: modelContainer)
                    runtime.processPendingRecordingRequests()
                }
                .onChange(of: scenePhase) { _, phase in
                    handleScenePhase(phase)
                }
                .onOpenURL { url in
                    runtime.bootstrap(container: modelContainer)
                    guard CarinhoDeepLink.handle(url) else { return }
                    runtime.processPendingRecordingRequests()
                    // Widget deep link can arrive before UI/auth is ready; retry once.
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(300))
                        runtime.processPendingRecordingRequests()
                    }
                }
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .background:
            didEnterBackground = true
            runtime.suspendIdleMonitoringIfNeeded()
        case .active:
            runtime.bootstrap(container: modelContainer)
            runtime.processPendingRecordingRequests()
            AppNotificationStore.shared.reload()
            runtime.resumeMonitoringIfNeeded()
            Task { @MainActor in
                await runtime.geocodingRetryService.retryPendingTrips(in: modelContainer.mainContext)
            }
            if AppSettings.shared.appLockEnabled, didEnterBackground {
                runtime.appLockService.lock()
                Task { @MainActor in
                    _ = await runtime.appLockService.authenticateIfNeeded(enabled: true)
                }
            }
        default:
            break
        }
    }
}
