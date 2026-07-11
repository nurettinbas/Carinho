import Foundation

enum PairedVehicleType: String, Codable {
    case bluetoothAudio
    case carPlay
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults: UserDefaults
    private let suiteName = "group.com.carinho.app"

    var hasCompletedOnboarding = false
    var hasCompletedCarSetup = false
    var monthlyDistanceGoalMeters: Double = 500_000 {
        didSet { defaults.set(monthlyDistanceGoalMeters, forKey: Key.monthlyDistanceGoalMeters) }
    }
    var idleTimeoutSeconds: TimeInterval = 60 {
        didSet { defaults.set(idleTimeoutSeconds, forKey: Key.idleTimeoutSeconds) }
    }
    var lowSpeedStopSeconds: TimeInterval = 60 {
        didSet { defaults.set(lowSpeedStopSeconds, forKey: Key.lowSpeedStopSeconds) }
    }
    var recordingStartSpeedKmh: Double = 15 {
        didSet { defaults.set(recordingStartSpeedKmh, forKey: Key.recordingStartSpeedKmh) }
    }
    var recordingStopSpeedKmh: Double = 5 {
        didSet { defaults.set(recordingStopSpeedKmh, forKey: Key.recordingStopSpeedKmh) }
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
    var gpsPendingTimeoutSeconds: TimeInterval = 300 {
        didSet { defaults.set(gpsPendingTimeoutSeconds, forKey: Key.gpsPendingTimeoutSeconds) }
    }

    private enum Key {
        static let autoRecording = "autoRecordingEnabled"
        static let recordingSounds = "recordingSoundsEnabled"
        static let fuelLitersPer100km = "fuelLitersPer100km"
        static let fuelPricePerLiter = "fuelPricePerLiter"
        static let evChargePricePerKWh = "evChargePricePerKWh"
        static let appLockEnabled = "appLockEnabled"
        static let confirmExternalRecordingStart = "confirmExternalRecordingStart"
        static let privacyRadiusMeters = "privacyRadiusMeters"
        static let autoDeleteDays = "autoDeleteDays"
        static let blurExportCoordinates = "blurExportCoordinates"
        static let bluetoothCarIdentifier = "bluetoothCarIdentifier"
        static let bluetoothCarName = "bluetoothCarName"
        static let hasCompletedCarSetup = "hasCompletedCarSetup"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let monthlyDistanceGoalMeters = "monthlyDistanceGoalMeters"
        static let pairedVehicleID = "pairedVehicleID"
        static let pairedVehicleName = "pairedVehicleName"
        static let pairedBluetoothUID = "pairedBluetoothUID"
        static let pairedVehicleType = "pairedVehicleType"
        static let pairedCarPlayChannelEnabled = "vehicle.paired.carplay.enabled"
        static let pairedBluetoothChannelEnabled = "vehicle.paired.bluetooth.enabled"
        static let activeAutoTriggerVehicleID = "activeAutoTriggerVehicleID"
        static let preferredLanguageCode = "preferredLanguageCode"
        static let idleTimeoutSeconds = "recording.idleTimeoutSeconds"
        static let lowSpeedStopSeconds = "recording.lowSpeedStopSeconds"
        static let recordingStartSpeedKmh = "recording.recordingStartSpeedKmh"
        static let recordingStopSpeedKmh = "recording.recordingStopSpeedKmh"
        static let stopSpeedKmh = "recording.stopSpeedKmh"
        static let stopMinimumDistanceMeters = "recording.stopMinimumDistanceMeters"
        static let stopMinimumDurationSeconds = "recording.stopMinimumDurationSeconds"
        static let tripStopMinimumDurationSeconds = "recording.tripStopMinimumDurationSeconds"
        static let gpsPendingTimeoutSeconds = "recording.gpsPendingTimeoutSeconds"
        static let developerModeEnabled = "developerModeEnabled"
        static let dismissedVehicleIdentityFingerprint = "vehicle.identity.dismissedFingerprint"
    }

    var awaitingVehicleIdentityConfirmation = false
    var vehicleIdentityConfirmationVehicleID: UUID?
    var vehicleIdentityConfirmationConnectionLabel: String?

    var dismissedVehicleIdentityFingerprint: String? {
        get { defaults.string(forKey: Key.dismissedVehicleIdentityFingerprint) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.dismissedVehicleIdentityFingerprint)
            } else {
                defaults.removeObject(forKey: Key.dismissedVehicleIdentityFingerprint)
            }
        }
    }

    func clearVehicleIdentityPrompt() {
        awaitingVehicleIdentityConfirmation = false
        vehicleIdentityConfirmationVehicleID = nil
        vehicleIdentityConfirmationConnectionLabel = nil
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
        idleTimeoutSeconds = Self.loadedTimeInterval(
            from: resolvedDefaults,
            key: Key.idleTimeoutSeconds,
            default: 60
        )
        lowSpeedStopSeconds = Self.loadedTimeInterval(
            from: resolvedDefaults,
            key: Key.lowSpeedStopSeconds,
            default: 60
        )
        recordingStartSpeedKmh = Self.loadedPositiveDouble(
            from: resolvedDefaults,
            key: Key.recordingStartSpeedKmh,
            default: 15
        )
        recordingStopSpeedKmh = Self.loadedPositiveDouble(
            from: resolvedDefaults,
            key: Key.recordingStopSpeedKmh,
            default: 5
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
        gpsPendingTimeoutSeconds = Self.loadedTimeInterval(
            from: resolvedDefaults,
            key: Key.gpsPendingTimeoutSeconds,
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

    var autoRecordingEnabled: Bool {
        get {
            if defaults.object(forKey: Key.autoRecording) == nil { return true }
            return defaults.bool(forKey: Key.autoRecording)
        }
        set { defaults.set(newValue, forKey: Key.autoRecording) }
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
            return value > 0 ? value : 42.0
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

    var bluetoothCarIdentifier: String? {
        get { pairedVehicleID }
        set { pairedVehicleID = newValue }
    }

    var bluetoothCarName: String? {
        get { pairedVehicleName }
        set { pairedVehicleName = newValue }
    }

    var pairedVehicleID: String? {
        get {
            defaults.string(forKey: Key.pairedVehicleID)
                ?? defaults.string(forKey: Key.bluetoothCarIdentifier)
        }
        set { defaults.set(newValue, forKey: Key.pairedVehicleID) }
    }

    var pairedVehicleName: String? {
        get {
            defaults.string(forKey: Key.pairedVehicleName)
                ?? defaults.string(forKey: Key.bluetoothCarName)
        }
        set { defaults.set(newValue, forKey: Key.pairedVehicleName) }
    }

    var pairedBluetoothUID: String? {
        get { defaults.string(forKey: Key.pairedBluetoothUID) }
        set { defaults.set(newValue, forKey: Key.pairedBluetoothUID) }
    }

    var bluetoothPairingIdentity: BluetoothPairingIdentity {
        BluetoothPairingIdentity(
            uid: pairedBluetoothUID,
            displayName: pairedVehicleName,
            legacyIdentifier: pairedVehicleID
        )
    }

    var developerModeEnabled: Bool {
        get { defaults.bool(forKey: Key.developerModeEnabled) }
        set { defaults.set(newValue, forKey: Key.developerModeEnabled) }
    }

    var pairedVehicleType: PairedVehicleType? {
        get {
            guard let raw = defaults.string(forKey: Key.pairedVehicleType) else {
                return pairedVehicleID == nil ? nil : .bluetoothAudio
            }
            return PairedVehicleType(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: Key.pairedVehicleType) }
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
        pairedVehicleID = nil
        pairedVehicleName = nil
        pairedBluetoothUID = nil
        pairedVehicleType = nil
        pairedCarPlayChannelEnabled = false
        pairedBluetoothChannelEnabled = false
    }

    func pairVehicle(id: String, name: String, type: PairedVehicleType) {
        pairVehicle(uid: id, legacyIdentifier: id, name: name, type: type)
    }

    func pairVehicle(uid: String?, legacyIdentifier: String, name: String, type: PairedVehicleType) {
        pairedBluetoothUID = type == .bluetoothAudio ? uid : nil
        pairedVehicleID = legacyIdentifier
        pairedVehicleName = name
        pairedVehicleType = type
        switch type {
        case .carPlay:
            pairedCarPlayChannelEnabled = true
            pairedBluetoothChannelEnabled = false
        case .bluetoothAudio:
            pairedBluetoothChannelEnabled = true
            pairedCarPlayChannelEnabled = false
        }
    }

    func learnPairedBluetoothUID(_ uid: String) {
        guard pairedBluetoothChannelEnabled else { return }
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        pairedBluetoothUID = trimmed
        pairedVehicleID = trimmed
    }

    var pairedCarPlayChannelEnabled: Bool {
        get { defaults.bool(forKey: Key.pairedCarPlayChannelEnabled) }
        set { defaults.set(newValue, forKey: Key.pairedCarPlayChannelEnabled) }
    }

    var pairedBluetoothChannelEnabled: Bool {
        get { defaults.bool(forKey: Key.pairedBluetoothChannelEnabled) }
        set { defaults.set(newValue, forKey: Key.pairedBluetoothChannelEnabled) }
    }

    var isPairedCarPlayVehicle: Bool {
        activeAutoTriggerVehicleID != nil && pairedCarPlayChannelEnabled
    }

    var isPairedBluetoothVehicle: Bool {
        activeAutoTriggerVehicleID != nil && pairedBluetoothChannelEnabled && pairedVehicleID != nil
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
        isPairedBluetoothVehicle || isPairedCarPlayVehicle
    }

    func syncRecordingState(
        isRecording: Bool,
        isPaused: Bool = false,
        isPendingGPS: Bool = false,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentSpeedKmh: Int = 0
    ) {
        defaults.set(isRecording || isPendingGPS, forKey: "recording.isActive")
        defaults.set(isPaused, forKey: "recording.isPaused")
        defaults.set(isPendingGPS, forKey: "recording.isPendingGPS")
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
