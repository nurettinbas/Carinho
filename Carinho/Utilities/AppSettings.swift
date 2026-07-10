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
        static let pairedVehicleType = "pairedVehicleType"
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
    }

    init(userDefaults: UserDefaults? = nil) {
        defaults = userDefaults ?? RecordingControlBridge.sharedDefaults()
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

    var pairedVehicleType: PairedVehicleType? {
        get {
            guard let raw = defaults.string(forKey: Key.pairedVehicleType) else {
                return pairedVehicleID == nil ? nil : .bluetoothAudio
            }
            return PairedVehicleType(rawValue: raw)
        }
        set { defaults.set(newValue?.rawValue, forKey: Key.pairedVehicleType) }
    }

    var preferredLanguageCode: String? {
        get { defaults.string(forKey: Key.preferredLanguageCode) }
        set { defaults.set(newValue, forKey: Key.preferredLanguageCode) }
    }

    var idleTimeoutSeconds: TimeInterval {
        get { timeInterval(forKey: Key.idleTimeoutSeconds, default: 60) }
        set { defaults.set(newValue, forKey: Key.idleTimeoutSeconds) }
    }

    var lowSpeedStopSeconds: TimeInterval {
        get { timeInterval(forKey: Key.lowSpeedStopSeconds, default: 60) }
        set { defaults.set(newValue, forKey: Key.lowSpeedStopSeconds) }
    }

    var recordingStartSpeedKmh: Double {
        get { positiveDouble(forKey: Key.recordingStartSpeedKmh, default: 15) }
        set { defaults.set(newValue, forKey: Key.recordingStartSpeedKmh) }
    }

    var recordingStopSpeedKmh: Double {
        get { positiveDouble(forKey: Key.recordingStopSpeedKmh, default: 5) }
        set { defaults.set(newValue, forKey: Key.recordingStopSpeedKmh) }
    }

    var stopSpeedKmh: Double {
        get { positiveDouble(forKey: Key.stopSpeedKmh, default: 2) }
        set { defaults.set(newValue, forKey: Key.stopSpeedKmh) }
    }

    var stopMinimumDistanceMeters: Double {
        get { positiveDouble(forKey: Key.stopMinimumDistanceMeters, default: 200) }
        set { defaults.set(newValue, forKey: Key.stopMinimumDistanceMeters) }
    }

    var stopMinimumDurationSeconds: TimeInterval {
        get { timeInterval(forKey: Key.stopMinimumDurationSeconds, default: 120) }
        set { defaults.set(newValue, forKey: Key.stopMinimumDurationSeconds) }
    }

    var tripStopMinimumDurationSeconds: TimeInterval {
        get { timeInterval(forKey: Key.tripStopMinimumDurationSeconds, default: 300) }
        set { defaults.set(newValue, forKey: Key.tripStopMinimumDurationSeconds) }
    }

    private func timeInterval(forKey key: String, default defaultValue: TimeInterval) -> TimeInterval {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        let value = defaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    private func positiveDouble(forKey key: String, default defaultValue: Double) -> Double {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        let value = defaults.double(forKey: key)
        return value > 0 ? value : defaultValue
    }

    var localizationBundle: Bundle {
        guard let code = preferredLanguageCode,
              let path = Bundle.main.path(forResource: code, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }

    func clearPairedVehicle() {
        pairedVehicleID = nil
        pairedVehicleName = nil
        pairedVehicleType = nil
    }

    func pairVehicle(id: String, name: String, type: PairedVehicleType) {
        pairedVehicleID = id
        pairedVehicleName = name
        pairedVehicleType = type
    }

    var isPairedCarPlayVehicle: Bool {
        pairedVehicleType == .carPlay && pairedVehicleID == VehicleConnectionKind.carPlayVehicleID
    }

    var isPairedBluetoothVehicle: Bool {
        pairedVehicleType == .bluetoothAudio && pairedVehicleID != nil
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

    var hasCompletedCarSetup: Bool {
        get { defaults.bool(forKey: Key.hasCompletedCarSetup) }
        set { defaults.set(newValue, forKey: Key.hasCompletedCarSetup) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }

    var monthlyDistanceGoalMeters: Double {
        get {
            let value = defaults.double(forKey: Key.monthlyDistanceGoalMeters)
            return value > 0 ? value : 500_000
        }
        set { defaults.set(newValue, forKey: Key.monthlyDistanceGoalMeters) }
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
