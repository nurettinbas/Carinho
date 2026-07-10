import ActivityKit
@preconcurrency import CoreFoundation
@preconcurrency import Foundation

public enum RecordingControlBridge {
    public static let appGroupSuiteName = "group.com.carinho.app"

    public enum Keys {
        public static let requestStop = "recording.requestStop"
        public static let requestStart = "recording.requestStart"
        public static let requestPause = "recording.requestPause"
        public static let requestResume = "recording.requestResume"
        public static let isActive = "recording.isActive"
        public static let isPaused = "recording.isPaused"
        public static let elapsed = "recording.elapsed"
        public static let distance = "recording.distance"
    }

    private enum DarwinNotification {
        static let stopRequestName = "com.carinho.recording.requestStop"
        static let startRequestName = "com.carinho.recording.requestStart"
        static let pauseRequestName = "com.carinho.recording.requestPause"
        static let resumeRequestName = "com.carinho.recording.requestResume"

        static func stopRequestCFName() -> CFNotificationName {
            CFNotificationName(stopRequestName as CFString)
        }

        static func startRequestCFName() -> CFNotificationName {
            CFNotificationName(startRequestName as CFString)
        }

        static func pauseRequestCFName() -> CFNotificationName {
            CFNotificationName(pauseRequestName as CFString)
        }

        static func resumeRequestCFName() -> CFNotificationName {
            CFNotificationName(resumeRequestName as CFString)
        }

        static func stopRequestCFString() -> CFString {
            stopRequestName as CFString
        }

        static func startRequestCFString() -> CFString {
            startRequestName as CFString
        }

        static func pauseRequestCFString() -> CFString {
            pauseRequestName as CFString
        }

        static func resumeRequestCFString() -> CFString {
            resumeRequestName as CFString
        }
    }

    public static func registerDarwinStartObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            DarwinNotification.startRequestCFString(),
            nil,
            .deliverImmediately
        )
    }

    public static func registerDarwinStopObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            DarwinNotification.stopRequestCFString(),
            nil,
            .deliverImmediately
        )
    }

    public static func registerDarwinPauseObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            DarwinNotification.pauseRequestCFString(),
            nil,
            .deliverImmediately
        )
    }

    public static func registerDarwinResumeObserver(
        observer: UnsafeRawPointer,
        callback: @escaping CFNotificationCallback
    ) {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            callback,
            DarwinNotification.resumeRequestCFString(),
            nil,
            .deliverImmediately
        )
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
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(false, forKey: Keys.requestStop)
        defaults?.set(false, forKey: Keys.requestPause)
        defaults?.set(false, forKey: Keys.requestResume)
        defaults?.set(true, forKey: Keys.requestStart)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DarwinNotification.startRequestCFName(),
            nil,
            nil,
            true
        )
    }

    public static func requestStopFromControlSurface() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(false, forKey: Keys.requestPause)
        defaults?.set(false, forKey: Keys.requestResume)
        defaults?.set(true, forKey: Keys.requestStop)
        defaults?.set(false, forKey: Keys.isActive)
        defaults?.set(false, forKey: Keys.isPaused)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DarwinNotification.stopRequestCFName(),
            nil,
            nil,
            true
        )
    }

    public static func requestPauseFromControlSurface() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(false, forKey: Keys.requestResume)
        defaults?.set(true, forKey: Keys.requestPause)
        defaults?.set(true, forKey: Keys.isPaused)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DarwinNotification.pauseRequestCFName(),
            nil,
            nil,
            true
        )
    }

    public static func requestResumeFromControlSurface() {
        let defaults = UserDefaults(suiteName: appGroupSuiteName)
        defaults?.set(false, forKey: Keys.requestPause)
        defaults?.set(true, forKey: Keys.requestResume)
        defaults?.set(false, forKey: Keys.isPaused)

        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            DarwinNotification.resumeRequestCFName(),
            nil,
            nil,
            true
        )
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
