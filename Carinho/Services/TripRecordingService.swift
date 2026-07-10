import CoreLocation
import Foundation
import SwiftData
import WidgetKit

enum TripRecordingState: Equatable {
    case idle
    case recording
    case paused

    var isActiveSession: Bool {
        self == .recording || self == .paused
    }
}

@MainActor
@Observable
final class TripRecordingService {
    private(set) var state: TripRecordingState = .idle
    private(set) var currentDistanceMeters: Double = 0
    private(set) var currentSpeedMps: Double = 0
    private(set) var recordingStartedAt: Date?
    private(set) var elapsedTime: TimeInterval = 0

    var activeTripID: UUID? { activeTrip?.id }

    private let locationService: LocationService
    private let geocodingService: GeocodingService
    private let motionActivityService: MotionActivityService
    private let settings: AppSettings

    private var modelContext: ModelContext?
    private var modelContainer: ModelContainer?
    private var activeTrip: Trip?
    private var lastRecordedLocation: CLLocation?
    private var pointSequence = 0
    private var pointsSinceLastSave = 0
    private let saveBatchSize = 10
    private var elapsedTimer: Timer?
    private var idleCheckTimer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var elapsedTimerTarget: ElapsedTimerTarget?
    @ObservationIgnored nonisolated(unsafe) private var idleCheckTimerTarget: IdleCheckTimerTarget?
    private var lastMovementAt: Date?
    private var maxSpeedMps: Double = 0
    private var currentStopStartedAt: Date?
    private var currentStopCoordinate: CLLocationCoordinate2D?
    private var lowSpeedStartedAt: Date?

    private var recordingStartSpeedMps: Double {
        settings.recordingStartSpeedKmh / 3.6
    }

    private var recordingStopSpeedMps: Double {
        settings.recordingStopSpeedKmh / 3.6
    }

    private var stopSpeedMps: Double {
        settings.stopSpeedKmh / 3.6
    }

    private static weak var elapsedTimerService: TripRecordingService?
    private static weak var idleCheckService: TripRecordingService?

    init(
        locationService: LocationService,
        geocodingService: GeocodingService,
        motionActivityService: MotionActivityService,
        settings: AppSettings = .shared
    ) {
        self.locationService = locationService
        self.geocodingService = geocodingService
        self.motionActivityService = motionActivityService
        self.settings = settings

        locationService.onLocationUpdate = { [weak self] location in
            Task { @MainActor in
                self?.handleLocationUpdate(location)
            }
        }

        motionActivityService.onAutomotiveChanged = { [weak self] isAutomotive in
            Task { @MainActor in
                self?.handleAutomotiveChange(isAutomotive)
            }
        }
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.modelContainer = modelContext.container
    }

    func startServices() {
        motionActivityService.refreshAuthorizationStatus()
        let needsMonitoring = settings.autoRecordingEnabled
            || settings.isPairedBluetoothVehicle
            || settings.isPairedCarPlayVehicle
        if needsMonitoring {
            if settings.autoRecordingEnabled {
                motionActivityService.startMonitoring()
            }
            locationService.requestPermission()
            locationService.startLowPowerMonitoring()
        }
    }

    func stopServices() {
        if state.isActiveSession {
            return
        }
        stopIdleServices()
    }

    func stopIdleServices() {
        motionActivityService.stopMonitoring()
        locationService.stopTracking()
        stopElapsedTimer()
        stopIdleCheckTimer()
    }

    func refreshAutoRecording(enabled: Bool) {
        if enabled {
            motionActivityService.startMonitoring()
            locationService.startLowPowerMonitoring()
        } else {
            motionActivityService.stopMonitoring()
            if state == .idle {
                locationService.stopTracking()
            }
        }
    }

    @discardableResult
    func startManualRecording() -> Bool {
        guard state == .idle else { return false }
        beginRecording(trigger: .manual)
        return state == .recording
    }

    func stopManualRecording() {
        processExternalStopRequest()
    }

    func processExternalStartRequest() {
        guard state == .idle else {
            settings.pendingStartRecordingRequest = false
            return
        }

        settings.pendingPauseRecordingRequest = false
        settings.pendingResumeRecordingRequest = false

        if startManualRecording() {
            settings.pendingStartRecordingRequest = false
        }
    }

    func processExternalStopRequest() {
        settings.pendingStopRecordingRequest = false
        guard state.isActiveSession else { return }
        stopRecording(saveTrip: true, reason: .manual)
    }

    func processExternalPauseRequest() {
        settings.pendingPauseRecordingRequest = false
        if state == .recording {
            pauseRecording()
        } else if state == .paused {
            syncExternalState(force: true)
        }
    }

    func processExternalResumeRequest() {
        settings.pendingResumeRecordingRequest = false
        if state == .paused {
            resumeRecording()
        } else if state == .recording {
            syncExternalState(force: true)
        }
    }

    func pauseRecording() {
        guard state == .recording else { return }
        updateElapsedTime()
        state = .paused
        stopElapsedTimer()
        syncExternalState(force: true)
    }

    func resumeRecording() {
        guard state == .paused else { return }
        recordingStartedAt = Date().addingTimeInterval(-elapsedTime)
        state = .recording
        startElapsedTimer()
        syncExternalState(force: true)
    }

    func handleVehicleConnected(trigger: VehicleRecordingTrigger) {
        switch trigger {
        case .carPlay:
            guard state == .idle else { return }
            guard settings.isPairedCarPlayVehicle else { return }
            beginRecording(trigger: .carPlay)
        case .bluetooth:
            guard state == .idle else { return }
            guard settings.isPairedBluetoothVehicle else { return }
            beginRecording(trigger: .bluetooth)
        case .manual, .automatic:
            break
        }
    }

    func handleVehicleDisconnected(trigger: VehicleRecordingTrigger) {
        switch trigger {
        case .carPlay:
            guard state == .recording, activeTrigger == .carPlay else { return }
            stopRecording(saveTrip: true, reason: .carPlay)
        case .bluetooth:
            guard state == .recording, activeTrigger == .bluetooth else { return }
            stopRecording(saveTrip: true, reason: .bluetooth)
        case .manual, .automatic:
            break
        }
    }

    func handleCarPlayConnected() {
        handleVehicleConnected(trigger: .carPlay)
    }

    func handleCarPlayDisconnected() {
        handleVehicleDisconnected(trigger: .carPlay)
    }

    func handleBluetoothConnected() {
        handleVehicleConnected(trigger: .bluetooth)
    }

    func handleBluetoothDisconnected() {
        handleVehicleDisconnected(trigger: .bluetooth)
    }

    private enum RecordingTrigger {
        case manual, automatic, carPlay, bluetooth
    }

    private enum StopReason {
        case manual, automatic, carPlay, bluetooth, idle
    }

    private var activeTrigger: RecordingTrigger = .manual

    func resumeRecording(trip: Trip) {
        guard state == .idle, modelContext != nil else { return }

        activeTrip = trip
        activeTrigger = .manual
        state = .recording
        recordingStartedAt = trip.startedAt
        currentDistanceMeters = trip.distanceMeters
        pointSequence = (trip.sortedPoints.last?.sequence ?? -1) + 1
        currentSpeedMps = 0
        elapsedTime = Date().timeIntervalSince(trip.startedAt)
        lastMovementAt = Date()
        maxSpeedMps = trip.maxSpeedMps ?? 0
        lastRecordedLocation = trip.sortedPoints.last?.location
        currentStopStartedAt = nil
        currentStopCoordinate = nil
        lowSpeedStartedAt = nil
        pointsSinceLastSave = 0

        locationService.requestPermission()
        locationService.startTracking()
        startElapsedTimer()
        stopIdleCheckTimer()
        RecordingLiveActivityService.start(startedAt: trip.startedAt)
        syncExternalState(force: true)

        Task { CarPlayConnectionHandler.shared.refreshCarPlayUI() }
    }

    private func handleAutomotiveChange(_ isAutomotive: Bool) {
        guard settings.autoRecordingEnabled else { return }

        if isAutomotive {
            if state == .idle {
                locationService.startLowPowerMonitoring()
            }
        } else if state.isActiveSession {
            scheduleIdleCheck()
        }
    }

    private func handleLocationUpdate(_ location: CLLocation) {
        if state == .idle, settings.autoRecordingEnabled, motionActivityService.isAutomotive {
            if location.speed >= recordingStartSpeedMps {
                beginRecording(trigger: .automatic)
            }
        }

        guard state == .recording else { return }

        updateElapsedTime()

        let speed = location.speed >= 0 ? location.speed : 0
        currentSpeedMps = speed
        if speed > maxSpeedMps { maxSpeedMps = speed }

        evaluateLowSpeedStop(speed: speed)

        if speed < stopSpeedMps {
            if currentStopStartedAt == nil {
                currentStopStartedAt = Date()
                currentStopCoordinate = location.coordinate
            }
        } else {
            finalizeStopIfNeeded()
            lastMovementAt = Date()
        }

        if let previous = lastRecordedLocation {
            let delta = location.distance(from: previous)
            if delta >= 5 {
                currentDistanceMeters += delta
                lastRecordedLocation = location
                appendPoint(from: location, speed: speed)
            }
        } else {
            lastRecordedLocation = location
            appendPoint(from: location, speed: speed)
        }

        syncExternalState()
    }

    private func finalizeStopIfNeeded() {
        guard let trip = activeTrip,
              let modelContext,
              let startedAt = currentStopStartedAt,
              let coordinate = currentStopCoordinate else { return }

        let duration = Date().timeIntervalSince(startedAt)
        guard duration >= settings.tripStopMinimumDurationSeconds else {
            currentStopStartedAt = nil
            currentStopCoordinate = nil
            return
        }

        let stop = TripStop(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            startedAt: startedAt,
            durationSeconds: duration,
            trip: trip
        )
        trip.stops.append(stop)
        modelContext.insert(stop)
        currentStopStartedAt = nil
        currentStopCoordinate = nil
    }

    private func beginRecording(trigger: RecordingTrigger) {
        guard state == .idle else { return }
        guard let modelContext else { return }

        activeTrigger = trigger
        state = .recording
        currentDistanceMeters = 0
        currentSpeedMps = 0
        lastRecordedLocation = nil
        pointSequence = 0
        pointsSinceLastSave = 0
        recordingStartedAt = Date()
        elapsedTime = 0
        lastMovementAt = Date()
        maxSpeedMps = 0
        currentStopStartedAt = nil
        currentStopCoordinate = nil
        lowSpeedStartedAt = nil

        let trip = Trip(startedAt: recordingStartedAt ?? Date())
        let vehicleTrigger: VehicleRecordingTrigger = switch trigger {
        case .manual: .manual
        case .automatic: .automatic
        case .carPlay: .carPlay
        case .bluetooth: .bluetooth
        }
        if let vehicle = VehicleResolver.resolveActiveVehicle(in: modelContext, trigger: vehicleTrigger, settings: settings) {
            VehicleResolver.assign(vehicle: vehicle, to: trip)
        }
        modelContext.insert(trip)
        activeTrip = trip

        locationService.requestPermission()
        locationService.startTracking()
        startElapsedTimer()
        stopIdleCheckTimer()
        RecordingLiveActivityService.start(startedAt: recordingStartedAt ?? Date())
        TripNotificationService.notifyTripStarted(tripID: trip.id)
        syncExternalState(force: true)

        Task {
            CarPlayConnectionHandler.shared.refreshCarPlayUI()
        }

        if let location = locationService.lastLocation {
            handleLocationUpdate(location)
        }
    }

    private func appendPoint(from location: CLLocation, speed: Double) {
        guard let trip = activeTrip, let modelContext else { return }

        let point = TripPoint(
            timestamp: location.timestamp,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            sequence: pointSequence,
            speedMps: speed > 0 ? speed : nil,
            trip: trip
        )
        pointSequence += 1
        trip.points.append(point)
        trip.distanceMeters = currentDistanceMeters
        trip.invalidatePointCaches()
        modelContext.insert(point)
        pointsSinceLastSave += 1
        if pointsSinceLastSave >= saveBatchSize {
            flushPointsToStore()
        }
    }

    private func flushPointsToStore() {
        guard let modelContext else { return }
        do {
            try modelContext.save()
            pointsSinceLastSave = 0
        } catch {
            AppErrorPresenter.shared.present(error.localizedDescription)
        }
    }

    private func stopRecording(saveTrip: Bool, reason: StopReason) {
        guard state.isActiveSession else { return }

        finalizeStopIfNeeded()
        state = .idle
        locationService.stopTracking()
        if settings.autoRecordingEnabled {
            locationService.startLowPowerMonitoring()
        }
        stopElapsedTimer()
        stopIdleCheckTimer()
        flushPointsToStore()
        RecordingLiveActivityService.stop()
        RecordingSyncCoordinator.reset()

        guard let trip = activeTrip, let modelContext else {
            resetActiveSession()
            return
        }

        TripNotificationService.cancelOrphanStaleNotification(tripID: trip.id)

        let endedAt = Date()
        let duration = endedAt.timeIntervalSince(trip.startedAt)
        let policyReason: RecordingStopPolicy.StopReason = switch reason {
        case .manual: .manual
        case .automatic: .automatic
        case .carPlay: .carPlay
        case .bluetooth: .bluetooth
        case .idle: .idle
        }
        let shouldSave = RecordingStopPolicy.shouldSaveTrip(
            saveTrip: saveTrip,
            reason: policyReason,
            duration: duration,
            distanceMeters: currentDistanceMeters,
            minimumDurationSeconds: settings.stopMinimumDurationSeconds,
            minimumDistanceMeters: settings.stopMinimumDistanceMeters
        )

        if shouldSave {
            trip.endedAt = endedAt
            trip.distanceMeters = currentDistanceMeters
            trip.maxSpeedMps = maxSpeedMps > 0 ? maxSpeedMps : nil
            trip.estimatedFuelCost = FuelCostCalculator.estimateCost(distanceMeters: currentDistanceMeters, vehicle: trip.vehicle)
            trip.geocodeStatus = .pending

            let places = (try? modelContext.fetch(FetchDescriptor<SavedPlace>())) ?? []
            PlaceMatchingService.matchPlaces(for: trip, places: places)
            let routeSummary = TripListViewModel.routeSummary(
                for: trip,
                places: places,
                privacyRadius: settings.privacyRadiusMeters
            )

            do {
                try modelContext.save()
            } catch {
                AppErrorPresenter.shared.present(error.localizedDescription)
            }
            TripNotificationService.notifyTripEnded(
                tripID: trip.id,
                distanceMeters: currentDistanceMeters,
                duration: duration,
                routeSummary: routeSummary
            )

            let tripID = trip.persistentModelID
            let container = modelContainer
            Task { @MainActor in
                guard let container else { return }
                await TripPostProcessor.process(
                    tripID: tripID,
                    container: container
                )
            }
        } else {
            if saveTrip {
                TripNotificationService.notifyTripDiscarded(tripID: trip.id)
            }
            modelContext.delete(trip)
            try? modelContext.save()
        }

        resetActiveSession()
        syncExternalState()
        WidgetCenter.shared.reloadAllTimelines()

        Task {
            CarPlayConnectionHandler.shared.refreshCarPlayUI()
        }
    }

    private func resetActiveSession() {
        activeTrip = nil
        lastRecordedLocation = nil
        pointSequence = 0
        pointsSinceLastSave = 0
        currentDistanceMeters = 0
        currentSpeedMps = 0
        recordingStartedAt = nil
        elapsedTime = 0
        maxSpeedMps = 0
        currentStopStartedAt = nil
        currentStopCoordinate = nil
        lowSpeedStartedAt = nil
    }

    private func evaluateLowSpeedStop(speed: Double) {
        guard state == .recording else { return }
        guard RecordingStopPolicy.shouldApplyIdleAutoStop(activeTriggerIsManual: activeTrigger == .manual) else {
            lowSpeedStartedAt = nil
            return
        }

        guard !motionActivityService.isAutomotive else {
            lowSpeedStartedAt = nil
            return
        }

        let noRecentMovement: Bool
        if let lastMovementAt {
            noRecentMovement = Date().timeIntervalSince(lastMovementAt) >= settings.lowSpeedStopSeconds
        } else {
            noRecentMovement = true
        }

        if speed < recordingStopSpeedMps && noRecentMovement {
            if lowSpeedStartedAt == nil {
                lowSpeedStartedAt = Date()
            } else if let started = lowSpeedStartedAt,
                      Date().timeIntervalSince(started) >= settings.lowSpeedStopSeconds {
                stopRecording(saveTrip: true, reason: .idle)
            }
        } else {
            lowSpeedStartedAt = nil
        }
    }

    private func syncExternalState(force: Bool = false) {
        guard force || RecordingSyncCoordinator.shouldSync() else { return }

        let speedKmh = Int(max(0, currentSpeedMps) * 3.6)
        let isPaused = state == .paused
        let isRecording = state == .recording
        settings.syncRecordingState(
            isRecording: isRecording || isPaused,
            isPaused: isPaused,
            elapsed: elapsedTime,
            distanceMeters: currentDistanceMeters,
            currentSpeedKmh: speedKmh
        )
        WatchConnectivityService.shared.sendRecordingState(
            isRecording: isRecording || isPaused,
            isPaused: isPaused,
            elapsed: elapsedTime,
            distanceMeters: currentDistanceMeters
        )
        RecordingLiveActivityService.update(
            elapsed: elapsedTime,
            distanceMeters: currentDistanceMeters,
            currentSpeedKmh: speedKmh,
            isPaused: isPaused,
            force: force
        )

        if state.isActiveSession, let tripID = activeTripID {
            AppNotificationStore.shared.syncLiveTripNotification(
                tripID: tripID,
                isPaused: isPaused,
                elapsed: elapsedTime,
                distanceMeters: currentDistanceMeters,
                currentSpeedKmh: speedKmh
            )
        }

        if force {
            WidgetCenter.shared.reloadAllTimelines()
        }

        Task { CarPlayConnectionHandler.shared.refreshCarPlayUI() }
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        Self.elapsedTimerService = self
        let target = ElapsedTimerTarget()
        elapsedTimerTarget = target
        let timer = Timer(timeInterval: 1, target: target, selector: #selector(ElapsedTimerTarget.tick(_:)), userInfo: nil, repeats: true)
        elapsedTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func updateElapsedTime() {
        guard let startedAt = recordingStartedAt else { return }
        elapsedTime = Date().timeIntervalSince(startedAt)
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        elapsedTimerTarget = nil
        if Self.elapsedTimerService === self {
            Self.elapsedTimerService = nil
        }
    }

    private func scheduleIdleCheck() {
        stopIdleCheckTimer()
        Self.idleCheckService = self
        let target = IdleCheckTimerTarget()
        idleCheckTimerTarget = target
        idleCheckTimer = Timer.scheduledTimer(
            timeInterval: settings.idleTimeoutSeconds,
            target: target,
            selector: #selector(IdleCheckTimerTarget.fire(_:)),
            userInfo: nil,
            repeats: false
        )
    }

    fileprivate func handleElapsedTimerTick() {
        updateElapsedTime()
        syncExternalState()
    }

    fileprivate func evaluateIdleCheck() {
        guard state == .recording else { return }
        guard RecordingStopPolicy.shouldApplyIdleAutoStop(activeTriggerIsManual: activeTrigger == .manual) else { return }

        let automotiveInactive = !motionActivityService.isAutomotive
        let noRecentMovement: Bool
        if let lastMovementAt {
            noRecentMovement = Date().timeIntervalSince(lastMovementAt) >= settings.idleTimeoutSeconds
        } else {
            noRecentMovement = true
        }

        let lowSpeedTooLong: Bool
        if let lowSpeedStartedAt {
            lowSpeedTooLong = Date().timeIntervalSince(lowSpeedStartedAt) >= settings.lowSpeedStopSeconds
        } else {
            lowSpeedTooLong = false
        }

        if state.isActiveSession,
           (automotiveInactive && noRecentMovement) || lowSpeedTooLong {
            stopRecording(saveTrip: true, reason: .idle)
        }
    }

    private func stopIdleCheckTimer() {
        idleCheckTimer?.invalidate()
        idleCheckTimer = nil
        idleCheckTimerTarget = nil
        if Self.idleCheckService === self {
            Self.idleCheckService = nil
        }
    }

    static func handleElapsedTimerTickFromBackground() {
        elapsedTimerService?.handleElapsedTimerTick()
    }

    static func handleIdleCheckFromBackground() {
        idleCheckService?.evaluateIdleCheck()
    }
}

private nonisolated func dispatchElapsedTimerTickToMainActor() {
    Task { @MainActor in
        TripRecordingService.handleElapsedTimerTickFromBackground()
    }
}

private nonisolated func dispatchIdleCheckToMainActor() {
    Task { @MainActor in
        TripRecordingService.handleIdleCheckFromBackground()
    }
}

private final class ElapsedTimerTarget: NSObject {
    @objc nonisolated func tick(_ timer: Timer) {
        dispatchElapsedTimerTickToMainActor()
    }
}

private final class IdleCheckTimerTarget: NSObject {
    @objc nonisolated func fire(_ timer: Timer) {
        dispatchIdleCheckToMainActor()
    }
}

@MainActor
enum TripPostProcessor {
    static func process(
        tripID: PersistentIdentifier,
        container: ModelContainer
    ) async {
        let context = ModelContext(container)
        guard let trip = context.model(for: tripID) as? Trip else { return }
        let geocodingService = GeocodingService()

        await enrichTripWithAddresses(trip, context: context, geocodingService: geocodingService)
        simplifyStoredPointsIfNeeded(for: trip, context: context)

        let places = (try? context.fetch(FetchDescriptor<SavedPlace>())) ?? []
        PlaceMatchingService.matchPlaces(for: trip, places: places)
        try? context.save()
    }

    private static func simplifyStoredPointsIfNeeded(for trip: Trip, context: ModelContext) {
        guard trip.points.count > 1000 else { return }

        let sorted = trip.sortedPoints
        let simplified = DistanceCalculator.simplify(coordinates: sorted.map(\.coordinate))
        guard simplified.count < sorted.count else { return }

        for point in trip.points { context.delete(point) }
        trip.points.removeAll()

        for (index, coordinate) in simplified.enumerated() {
            let point = TripPoint(
                timestamp: trip.startedAt.addingTimeInterval(TimeInterval(index)),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                sequence: index,
                trip: trip
            )
            trip.points.append(point)
            context.insert(point)
        }
        trip.invalidatePointCaches()
    }

    private static func enrichTripWithAddresses(
        _ trip: Trip,
        context: ModelContext,
        geocodingService: GeocodingService
    ) async {
        var success = true

        if let startCoordinate = trip.startCoordinate {
            let startLocation = CLLocation(latitude: startCoordinate.latitude, longitude: startCoordinate.longitude)
            let address = await geocodingService.reverseGeocode(startLocation)
            trip.startAddress = address
            if address == nil { success = false }
        }

        if let endCoordinate = trip.endCoordinate {
            let endLocation = CLLocation(latitude: endCoordinate.latitude, longitude: endCoordinate.longitude)
            let address = await geocodingService.reverseGeocode(endLocation)
            trip.endAddress = address
            if address == nil { success = false }
        }

        trip.geocodeStatus = success ? .complete : .failed
        try? context.save()
    }
}
