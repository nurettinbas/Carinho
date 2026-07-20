import ActivityKit
import Foundation

@MainActor
enum RecordingLiveActivityService {
    private static let logCategory: DevLogCategory = .widget
    private static var lastUpdateAt: Date?
    private static var lastPublishedIsPaused: Bool?
    private static let minimumUpdateInterval: TimeInterval = 2
    private static var operationChain: Task<Void, Never>?

    /// Ends orphan Live Activities left over from a prior process (e.g. Xcode debug restart).
    static func reconcileAfterLaunch(hasActiveSession: Bool) async {
        await runSerially {
            guard !hasActiveSession else { return }
            guard !Activity<TripRecordingAttributes>.activities.isEmpty else { return }
            await endAllImmediately()
        }
    }

    static func start(
        startedAt: Date,
        elapsed: TimeInterval = 0,
        distanceMeters: Double = 0,
        currentSpeedKmh: Int = 0,
        isPaused: Bool = false
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        enqueue {
            await endAllImmediately()
            await requestActivity(
                startedAt: startedAt,
                elapsed: elapsed,
                distanceMeters: distanceMeters,
                currentSpeedKmh: currentSpeedKmh,
                isPaused: isPaused,
                logMessage: "Live Activity started"
            )
            lastUpdateAt = nil
            lastPublishedIsPaused = isPaused
        }
    }

    /// Re-creates the Live Activity if recording is active but the system dismissed it.
    static func ensureActiveIfNeeded(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentSpeedKmh: Int,
        isPaused: Bool
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        enqueue {
            await dedupeActivitiesIfNeeded()
            guard Activity<TripRecordingAttributes>.activities.isEmpty else { return }
            DevLog.shared.log(logCategory, "Live Activity missing during recording; restarting", level: .warning)
            await requestActivity(
                startedAt: startedAt,
                elapsed: elapsed,
                distanceMeters: distanceMeters,
                currentSpeedKmh: currentSpeedKmh,
                isPaused: isPaused,
                logMessage: "Live Activity restarted"
            )
            lastUpdateAt = nil
            lastPublishedIsPaused = isPaused
        }
    }

    static func update(
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentSpeedKmh: Int,
        isPaused: Bool,
        force: Bool = false
    ) {
        let pauseStateChanged = lastPublishedIsPaused != isPaused
        let now = Date()
        if !force,
           !pauseStateChanged,
           let lastUpdateAt,
           now.timeIntervalSince(lastUpdateAt) < minimumUpdateInterval {
            return
        }
        lastUpdateAt = now
        lastPublishedIsPaused = isPaused

        let state = TripRecordingAttributes.ContentState(
            elapsedSeconds: Int(elapsed.rounded()),
            distanceMeters: distanceMeters,
            currentSpeedKmh: currentSpeedKmh,
            isPaused: isPaused
        )
        let content = ActivityContent(state: state, staleDate: nil)

        enqueue {
            await dedupeActivitiesIfNeeded()
            guard !Activity<TripRecordingAttributes>.activities.isEmpty else { return }
            for activity in Activity<TripRecordingAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func stop() {
        lastUpdateAt = nil
        lastPublishedIsPaused = nil
        enqueue {
            await endAllImmediately()
        }
    }

    private static func enqueue(_ operation: @MainActor @escaping () async -> Void) {
        let waitFor = operationChain
        operationChain = Task { @MainActor in
            await waitFor?.value
            await operation()
        }
    }

    private static func runSerially(_ operation: @MainActor @escaping () async -> Void) async {
        let waitFor = operationChain
        let task = Task { @MainActor in
            await waitFor?.value
            await operation()
        }
        operationChain = task
        await task.value
    }

    private static func requestActivity(
        startedAt: Date,
        elapsed: TimeInterval,
        distanceMeters: Double,
        currentSpeedKmh: Int,
        isPaused: Bool,
        logMessage: String
    ) async {
        let attributes = TripRecordingAttributes(startedAt: startedAt)
        let state = TripRecordingAttributes.ContentState(
            elapsedSeconds: Int(elapsed.rounded()),
            distanceMeters: distanceMeters,
            currentSpeedKmh: currentSpeedKmh,
            isPaused: isPaused
        )
        do {
            _ = try Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
            DevLog.shared.log(logCategory, logMessage)
            await dedupeActivitiesIfNeeded()
        } catch {
            DevLog.shared.log(logCategory, "Live Activity start failed: \(error.localizedDescription)", level: .error)
        }
    }

    private static func dedupeActivitiesIfNeeded() async {
        let activities = Activity<TripRecordingAttributes>.activities
        guard activities.count > 1 else { return }
        DevLog.shared.log(
            logCategory,
            "Live Activity duplicate count=\(activities.count); ending extras",
            level: .warning
        )
        for activity in activities.dropLast() {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private static func endAllImmediately() async {
        for activity in Activity<TripRecordingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
