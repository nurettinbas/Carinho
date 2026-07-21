import Foundation

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let suiteName = "group.com.trailhound.app"

    var hasCompletedOnboarding = false
    var hasCompletedCarSetup = false
    var monthlyDistanceGoalMeters: Double = 500_000 {
        didSet { defaults.set(monthlyDistanceGoalMeters, forKey: Key.monthlyDistanceGoalMeters) }
    }
    var stopSpeedKmh: Double = 2 {
        didSet { defaults.set(stopSpeedKmh, forKey: Key.stopSpeedKmh) }
    }
    var stopMinimumDistanceMeters: Double = 200 {
        didSet { defaults.set(stopMinimumDistanceMeters, forKey: Key.stopMinimumDistanceMeters) }
    }
    var stopMinimumDurationSeconds: TimeInterval = 120 {
        didSet { defaults.set(stopMinimumDurationSeconds, forKey: Key.stopMinimumDurationSeconds) }
    }
    var tripStopMinimumDurationSeconds: TimeInterval = 300 {
        didSet { defaults.set(tripStopMinimumDurationSeconds, forKey: Key.tripStopMinimumDurationSeconds) }
    }

    private enum Key {
        static let recordingSounds = "recordingSoundsEnabled"
        static let fuelLitersPer100km = "fuelLitersPer100km"
        static let fuelPricePerLiter = "fuelPricePerLiter"
        static let evChargePricePerKWh = "evChargePricePerKWh"
        static let appLockEnabled = "appLockEnabled"
        static let confirmExternalRecordingStart = RecordingControlBridge.Keys.confirmExternalRecordingStart
        static let privacyRadiusMeters = "privacyRadiusMeters"
        static let autoDeleteDays = "autoDeleteDays"
        static let blurExportCoordinates = "blurExportCoordinates"
        static let hasCompletedCarSetup = "hasCompletedCarSetup"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let monthlyDistanceGoalMeters = "monthlyDistanceGoalMeters"
        static let pairedVehicleName = "pairedVehicleName"
        static let pairedRouteUID = "pairedRouteUID"
        static let activeAutoTriggerVehicleID = "activeAutoTriggerVehicleID"
        static let preferredLanguageCode = "preferredLanguageCode"
        static let stopSpeedKmh = "recording.stopSpeedKmh"
        static let stopMinimumDistanceMeters = "recording.stopMinimumDistanceMeters"
        static let stopMinimumDurationSeconds = "recording.stopMinimumDurationSeconds"
        static let tripStopMinimumDurationSeconds = "recording.tripStopMinimumDurationSeconds"
        static let developerModeEnabled = "developerModeEnabled"
    }

    init(userDefaults: UserDefaults? = nil) {
        let resolvedDefaults = userDefaults ?? RecordingControlBridge.sharedDefaults()
        defaults = resolvedDefaults
        hasCompletedOnboarding = resolvedDefaults.bool(forKey: Key.hasCompletedOnboarding)
        hasCompletedCarSetup = resolvedDefaults.bool(forKey: Key.hasCompletedCarSetup)
        resolvedDefaults.removeObject(forKey: Key.preferredLanguageCode)
        monthlyDistanceGoalMeters = Self.loadedPositiveDouble(
            from: resolvedDefaults,
            key: Key.monthlyDistanceGoalMeters,
            default: 500_000
        )
        stopSpeedKmh = Self.loadedPositiveDouble(
            from: resolvedDefaults,
            key: Key.stopSpeedKmh,
            default: 2
        )
        stopMinimumDistanceMeters = Self.loadedPositiveDouble(
            from: resolvedDefaults,
            key: Key.stopMinimumDistanceMeters,
            default: 200
        )
        stopMinimumDurationSeconds = Self.loadedTimeInterval(
            from: resolvedDefaults,
            key: Key.stopMinimumDurationSeconds,
            default: 120
        )
        tripStopMinimumDurationSeconds = Self.loadedTimeInterval(
            from: resolvedDefaults,
            key: Key.tripStopMinimumDurationSeconds,
            default: 300
        )
    }

    func completeOnboarding() {
        guard !hasCompletedOnboarding else { return }
        hasCompletedOnboarding = true
        defaults.set(true, forKey: Key.hasCompletedOnboarding)
    }

    func skipCarSetup() {
        if !hasCompletedCarSetup {
            hasCompletedCarSetup = true
            defaults.set(true, forKey: Key.hasCompletedCarSetup)
        }
    }

    var recordingSoundsEnabled: Bool {
        get {
            if defaults.object(forKey: Key.recordingSounds) == nil { return true }
            return defaults.bool(forKey: Key.recordingSounds)
        }
        set { defaults.set(newValue, forKey: Key.recordingSounds) }
    }

    var fuelLitersPer100km: Double {
        get {
            let value = defaults.double(forKey: Key.fuelLitersPer100km)
            return value > 0 ? value : 7.5
        }
        set { defaults.set(newValue, forKey: Key.fuelLitersPer100km) }
    }

    var fuelPricePerLiter: Double {
        get {
            let value = defaults.double(forKey: Key.fuelPricePerLiter)
            return value > 0 ? value : 65.0
        }
        set { defaults.set(newValue, forKey: Key.fuelPricePerLiter) }
    }

    var evChargePricePerKWh: Double {
        get {
            let value = defaults.double(forKey: Key.evChargePricePerKWh)
            return value > 0 ? value : 8.5
        }
        set { defaults.set(newValue, forKey: Key.evChargePricePerKWh) }
    }

    var appLockEnabled: Bool {
        get { defaults.bool(forKey: Key.appLockEnabled) }
        set { defaults.set(newValue, forKey: Key.appLockEnabled) }
    }

    var confirmExternalRecordingStart: Bool {
        get { defaults.bool(forKey: Key.confirmExternalRecordingStart) }
        set { defaults.set(newValue, forKey: Key.confirmExternalRecordingStart) }
    }

    var awaitingExternalStartConfirmation: Bool {
        get { defaults.bool(forKey: "recording.awaitingExternalStartConfirmation") }
        set { defaults.set(newValue, forKey: "recording.awaitingExternalStartConfirmation") }
    }

    var privacyRadiusMeters: Double {
        get {
            let value = defaults.double(forKey: Key.privacyRadiusMeters)
            return value > 0 ? value : 500
        }
        set { defaults.set(newValue, forKey: Key.privacyRadiusMeters) }
    }

    var autoDeleteDays: Int {
        get {
            let value = defaults.integer(forKey: Key.autoDeleteDays)
            return value
        }
        set { defaults.set(newValue, forKey: Key.autoDeleteDays) }
    }

    var blurExportCoordinates: Bool {
        get { defaults.bool(forKey: Key.blurExportCoordinates) }
        set { defaults.set(newValue, forKey: Key.blurExportCoordinates) }
    }

    var pairedVehicleName: String? {
        get { defaults.string(forKey: Key.pairedVehicleName) }
        set { defaults.set(newValue, forKey: Key.pairedVehicleName) }
    }

    /// UID (or normalized name) of the Bluetooth audio route bound to the active
    /// auto-start vehicle. Only this route triggers connect-start / disconnect-stop.
    var pairedRouteUID: String? {
        get { defaults.string(forKey: Key.pairedRouteUID) }
        set { defaults.set(newValue, forKey: Key.pairedRouteUID) }
    }

    var pairingIdentity: BluetoothPairingIdentity {
        BluetoothPairingIdentity(uid: pairedRouteUID, displayName: pairedVehicleName)
    }

    var developerModeEnabled: Bool {
        get { defaults.bool(forKey: Key.developerModeEnabled) }
        set { defaults.set(newValue, forKey: Key.developerModeEnabled) }
    }

    private static func loadedTimeInterval(
        from defaults: UserDefaults,
        key: String,
        default defaultValue: TimeInterval
    ) -> TimeInterval {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        let value = defaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    private static func loadedPositiveDouble(
        from defaults: UserDefaults,
        key: String,
        default defaultValue: Double
    ) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        let value = defaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    func clearPairedVehicle() {
        pairedVehicleName = nil
        pairedRouteUID = nil
    }

    func pairVehicle(uid: String?, name: String) {
        pairedRouteUID = uid
        pairedVehicleName = name
    }

    var activeAutoTriggerVehicleID: UUID? {
        get {
            guard let raw = defaults.string(forKey: Key.activeAutoTriggerVehicleID) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            if let newValue {
                defaults.set(newValue.uuidString, forKey: Key.activeAutoTriggerVehicleID)
            } else {
                defaults.removeObject(forKey: Key.activeAutoTriggerVehicleID)
            }
        }
    }

    var hasAutoTriggerVehicle: Bool {
        activeAutoTriggerVehicleID != nil && pairedRouteUID != nil
    }

    func syncRecordingState(
        isRecording: Bool,
        isPaused: Bool = false,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentSpeedKmh: Int = 0
    ) {
        defaults.set(isRecording, forKey: "recording.isActive")
        defaults.set(isPaused, forKey: "recording.isPaused")
        defaults.removeObject(forKey: "recording.isPendingGPS")
        defaults.set(elapsed, forKey: "recording.elapsed")
        defaults.set(distanceMeters, forKey: "recording.distance")
        defaults.set(currentSpeedKmh, forKey: "recording.currentSpeedKmh")
    }

    var pendingStartRecordingRequest: Bool {
        get { defaults.bool(forKey: "recording.requestStart") }
        set {
            defaults.set(newValue, forKey: "recording.requestStart")
            if newValue {
                defaults.set(Date().timeIntervalSince1970, forKey: "recording.requestStartAt")
            } else {
                defaults.removeObject(forKey: "recording.requestStartAt")
            }
        }
    }

    var pendingStopRecordingRequest: Bool {
        get { defaults.bool(forKey: "recording.requestStop") }
        set {
            defaults.set(newValue, forKey: "recording.requestStop")
            if newValue {
                defaults.set(Date().timeIntervalSince1970, forKey: "recording.requestStopAt")
            } else {
                defaults.removeObject(forKey: "recording.requestStopAt")
            }
        }
    }

    var pendingPauseRecordingRequest: Bool {
        get { defaults.bool(forKey: "recording.requestPause") }
        set {
            defaults.set(newValue, forKey: "recording.requestPause")
            if newValue {
                defaults.set(Date().timeIntervalSince1970, forKey: "recording.requestPauseAt")
            } else {
                defaults.removeObject(forKey: "recording.requestPauseAt")
            }
        }
    }

    var pendingResumeRecordingRequest: Bool {
        get { defaults.bool(forKey: "recording.requestResume") }
        set {
            defaults.set(newValue, forKey: "recording.requestResume")
            if newValue {
                defaults.set(Date().timeIntervalSince1970, forKey: "recording.requestResumeAt")
            } else {
                defaults.removeObject(forKey: "recording.requestResumeAt")
            }
        }
    }

    private static let recordingRequestTTL: TimeInterval = 60

    func expireStaleRecordingRequests() {
        let now = Date().timeIntervalSince1970
        if pendingStartRecordingRequest,
           now - defaults.double(forKey: "recording.requestStartAt") > Self.recordingRequestTTL {
            pendingStartRecordingRequest = false
        }
        if pendingStopRecordingRequest,
           now - defaults.double(forKey: "recording.requestStopAt") > Self.recordingRequestTTL {
            pendingStopRecordingRequest = false
        }
        if pendingPauseRecordingRequest,
           now - defaults.double(forKey: "recording.requestPauseAt") > Self.recordingRequestTTL {
            pendingPauseRecordingRequest = false
        }
        if pendingResumeRecordingRequest,
           now - defaults.double(forKey: "recording.requestResumeAt") > Self.recordingRequestTTL {
            pendingResumeRecordingRequest = false
        }
    }
}
