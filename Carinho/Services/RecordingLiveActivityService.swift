import ActivityKit
import Foundation

enum RecordingLiveActivityService {
    nonisolated(unsafe) private static var lastUpdateAt: Date?
    nonisolated(unsafe) private static var lastPublishedIsPaused: Bool?
    private static let minimumUpdateInterval: TimeInterval = 2

    /// Ends orphan Live Activities left over from a prior process (e.g. Xcode debug restart).
    @MainActor
    static func reconcileAfterLaunch(hasActiveSession: Bool) async {
        guard !hasActiveSession else { return }
        guard !Activity<TripRecordingAttributes>.activities.isEmpty else { return }
        await endAllImmediately()
    }

    static func start(
        startedAt: Date,
        elapsed: TimeInterval = 0,
        distanceMeters: Double = 0,
        currentSpeedKmh: Int = 0,
        isPaused: Bool = false
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        Task { @MainActor in
            await endAllImmediately()
            let attributes = TripRecordingAttributes(startedAt: startedAt)
            let state = TripRecordingAttributes.ContentState(
                elapsedSeconds: Int(elapsed.rounded()),
                distanceMeters: distanceMeters,
                currentSpeedKmh: currentSpeedKmh,
                isPaused: isPaused
            )
            _ = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
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
        guard !Activity<TripRecordingAttributes>.activities.isEmpty else { return }

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
        Task { @MainActor in
            for activity in Activity<TripRecordingAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func stop() {
        lastUpdateAt = nil
        lastPublishedIsPaused = nil
        Task { @MainActor in
            await endAllImmediately()
        }
    }

    @MainActor
    private static func endAllImmediately() async {
        for activity in Activity<TripRecordingAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
