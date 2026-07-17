import SwiftData
import SwiftUI
import WidgetKit

@MainActor
@Observable
final class AppRuntime {
    private var location: LocationService?
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
            locationService: locationService
        )
        recording = service
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
        VehicleConnectionCoordinator.shared.configure(
            recordingService: tripRecordingService,
            bluetoothService: bluetoothService
        )
        tripRecordingService.startServices()
        wireVehicleConnectionHandlers(container: container)
        wireMonitoringWake()
        wireRecordingRequestHandlers()
        bluetoothService.syncRouteSnapshot()
        reconcileRecordingStateAfterLaunch()
    }

    private func reconcileRecordingStateAfterLaunch() {
        let recordingService = tripRecordingService
        guard !recordingService.state.isActiveSession else { return }

        AppSettings.shared.syncRecordingState(
            isRecording: false,
            isPaused: false,
            elapsed: 0,
            distanceMeters: 0,
            currentSpeedKmh: 0
        )

        Task { @MainActor in
            await RecordingLiveActivityService.reconcileAfterLaunch(hasActiveSession: false)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    func bootstrap(container: ModelContainer) {
        bootstrapRecording(container: container)
        guard !didFullBootstrap else { return }
        didFullBootstrap = true

        networkMonitor.startIfNeeded()
        CategorySeeder.seedIfNeeded(in: container.mainContext)
        VehiclePairingService.seedDefaultVehicleIfNeeded(in: container.mainContext)
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
            || settings.hasAutoTriggerVehicle
    }

    func resumeMonitoringIfNeeded() {
        if shouldKeepVehicleMonitoring {
            DevLog.shared.log(.lifecycle, "resumeMonitoringIfNeeded: resuming vehicle monitoring")
            tripRecordingService.startServices()
            refreshVehicleConnections()
        }
    }

    func refreshVehicleConnections() {
        // Re-evaluate with snapshot reporting so foreground/wake can drive connect.
        bluetoothService.syncRouteSnapshot()
        VehicleConnectionCoordinator.shared.refreshLiveSnapshots()
    }

    func suspendIdleMonitoringIfNeeded() {
        guard !shouldKeepVehicleMonitoring else {
            DevLog.shared.log(.lifecycle, "suspendIdleMonitoringIfNeeded: kept active (session or paired vehicle)")
            return
        }
        DevLog.shared.log(.lifecycle, "suspendIdleMonitoringIfNeeded: stopping idle services")
        tripRecordingService.stopIdleServices()
    }

    private func wireVehicleConnectionHandlers(container: ModelContainer) {
        // The route monitor reports the paired Bluetooth audio route, so a route
        // snapshot change is a vehicle connect/disconnect signal.
        bluetoothService.onRouteSnapshotChanged = { isConnected in
            VehicleConnectionCoordinator.shared.handleVehicleSnapshot(isConnected: isConnected)
        }
    }

    private func wireMonitoringWake() {
        locationService.onMonitoringWake = { [weak self] in
            guard let self else { return }
            if self.tripRecordingService.state.isActiveSession
                || AppSettings.shared.hasAutoTriggerVehicle {
                self.refreshVehicleConnections()
            }
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
struct TrailhoundApp: App {
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
                    guard TrailhoundDeepLink.handle(url) else { return }
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
        DevLog.shared.log(.lifecycle, "scenePhase -> \(phase)")
        switch phase {
        case .background:
            didEnterBackground = true
            runtime.suspendIdleMonitoringIfNeeded()
        case .active:
            runtime.bootstrap(container: modelContainer)
            runtime.processPendingRecordingRequests()
            AppNotificationStore.shared.reload()
            runtime.resumeMonitoringIfNeeded()
            refreshLockScreenWidgetStats()
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

    /// Re-writes the App Group distance stats and refreshes the accessory
    /// (lock-screen) widget whenever the app comes to the foreground. The
    /// once-only `bootstrap` guard skips this on background→foreground returns,
    /// so the monthly ring could otherwise show a stale value until relaunch.
    /// Note: lock-screen widget reloads are still subject to WidgetKit's system
    /// reload budget, so this maximizes freshness but cannot guarantee instant updates.
    private func refreshLockScreenWidgetStats() {
        TripStore.syncWidgetWeekDistance(in: modelContainer.mainContext)
        WidgetCenter.shared.reloadTimelines(ofKind: "TrailhoundLockScreenWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "TrailhoundWidget")
    }
}
