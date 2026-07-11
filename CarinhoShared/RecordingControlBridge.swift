import ActivityKit
@preconcurrency import CoreFoundation
@preconcurrency import Foundation

public enum RecordingControlBridge {
    public static let appGroupSuiteName = "group.com.carinho.app"

    private struct UncheckedDefaults: @unchecked Sendable {
        let value: UserDefaults
    }

    private static let uncheckedSharedDefaults = UncheckedDefaults(
        value: UserDefaults(suiteName: appGroupSuiteName) ?? .standard
    )

    /// Cached app-group defaults; avoids repeated `UserDefaults(suiteName:)` calls that spam cfprefsd logs.
    public static func sharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: appGroupSuiteName) ?? uncheckedSharedDefaults.value
    }

    private static func stampRequest(_ key: String, at timestampKey: String, in defaults: UserDefaults) {
        defaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
        defaults.set(true, forKey: key)
    }

    public enum Keys {
        public static let requestStop = "recording.requestStop"
        public static let requestStart = "recording.requestStart"
        public static let requestPause = "recording.requestPause"
        public static let requestResume = "recording.requestResume"
        public static let requestStartAt = "recording.requestStartAt"
        public static let requestStopAt = "recording.requestStopAt"
        public static let requestPauseAt = "recording.requestPauseAt"
        public static let requestResumeAt = "recording.requestResumeAt"
        public static let isActive = "recording.isActive"
        public static let isPaused = "recording.isPaused"
        public static let elapsed = "recording.elapsed"
        public static let distance = "recording.distance"
    }

    private enum DarwinNotification: CaseIterable {
        case start
        case stop
        case pause
        case resume

        var name: String {
            switch self {
            case .start: "com.carinho.recording.requestStart"
            case .stop: "com.carinho.recording.requestStop"
            case .pause: "com.carinho.recording.requestPause"
            case .resume: "com.carinho.recording.requestResume"
            }
        }

        var cfName: CFNotificationName {
            CFNotificationName(name as CFString)
        }

        var cfString: CFString {
            name as CFString
        }
    }

    private static func registerDarwinObserver(
        _ notification: DarwinNotification,
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            notification.cfString,
            nil,
            .deliverImmediately
        )
    }

    private static func postDarwinNotification(_ notification: DarwinNotification) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notification.cfName,
            nil,
            nil,
            true
        )
    }

    public static func registerDarwinStartObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        registerDarwinObserver(.start, observer: observer, callback: callback)
    }

    public static func registerDarwinStopObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        registerDarwinObserver(.stop, observer: observer, callback: callback)
    }

    public static func registerDarwinPauseObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        registerDarwinObserver(.pause, observer: observer, callback: callback)
    }

    public static func registerDarwinResumeObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        registerDarwinObserver(.resume, observer: observer, callback: callback)
    }

    @MainActor
    public static func endAllLiveActivitiesImmediately() async {
        for activity in Activity<TripRecordingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @MainActor
    public static func updateLiveActivities(isPaused: Bool) async {
        for activity in Activity<TripRecordingAttributes>.activities {
            var state = activity.content.state
            state.isPaused = isPaused
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    public static func requestStartFromControlSurface() {
        let defaults = sharedDefaults()
        defaults.set(false, forKey: Keys.requestStop)
        defaults.set(false, forKey: Keys.requestPause)
        defaults.set(false, forKey: Keys.requestResume)
        stampRequest(Keys.requestStart, at: Keys.requestStartAt, in: defaults)
        postDarwinNotification(.start)
    }

    public static func requestStopFromControlSurface() {
        let defaults = sharedDefaults()
        defaults.set(false, forKey: Keys.requestPause)
        defaults.set(false, forKey: Keys.requestResume)
        stampRequest(Keys.requestStop, at: Keys.requestStopAt, in: defaults)
        defaults.set(false, forKey: Keys.isActive)
        defaults.set(false, forKey: Keys.isPaused)
        postDarwinNotification(.stop)
    }

    public static func requestPauseFromControlSurface() {
        let defaults = sharedDefaults()
        defaults.set(false, forKey: Keys.requestResume)
        stampRequest(Keys.requestPause, at: Keys.requestPauseAt, in: defaults)
        defaults.set(true, forKey: Keys.isPaused)
        postDarwinNotification(.pause)
    }

    public static func requestResumeFromControlSurface() {
        let defaults = sharedDefaults()
        defaults.set(false, forKey: Keys.requestPause)
        stampRequest(Keys.requestResume, at: Keys.requestResumeAt, in: defaults)
        defaults.set(false, forKey: Keys.isPaused)
        postDarwinNotification(.resume)
    }

    @MainActor
    public static func handleStartButtonPressed() async {
        requestStartFromControlSurface()
    }

    @MainActor
    public static func handleStopButtonPressed() async {
        requestStopFromControlSurface()
        await endAllLiveActivitiesImmediately()
    }

    @MainActor
    public static func handlePauseButtonPressed() async {
        requestPauseFromControlSurface()
        await updateLiveActivities(isPaused: true)
    }

    @MainActor
    public static func handleResumeButtonPressed() async {
        requestResumeFromControlSurface()
        await updateLiveActivities(isPaused: false)
    }
}

public enum CarinhoDeepLink {
    public static let startRecording = URL(string: "carinho://recording/start")!

    @discardableResult
    public static func handle(_ url: URL) -> Bool {
        guard url.scheme == "carinho", url.host == "recording" else { return false }
        switch url.path {
        case "/start":
            RecordingControlBridge.requestStartFromControlSurface()
            return true
        default:
            return false
        }
    }
}
