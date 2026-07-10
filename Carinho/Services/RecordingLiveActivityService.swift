import ActivityKit
import Foundation

enum RecordingLiveActivityService {
    nonisolated(unsafe) private static var lastUpdateAt: Date?
    nonisolated(unsafe) private static var lastPublishedIsPaused: Bool?
    private static let minimumUpdateInterval: TimeInterval = 2

    static func start(startedAt: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = TripRecordingAttributes(startedAt: startedAt)
        let state = TripRecordingAttributes.ContentState(
            elapsedSeconds: 0,
            distanceMeters: 0,
            currentSpeedKmh: 0,
            isPaused: false
        )
        _ = try? Activity.request(attributes: attributes, content: .init(state: state, staleDate: nil))
        lastUpdateAt = nil
        lastPublishedIsPaused = false
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
        Task {
            for activity in Activity<TripRecordingAttributes>.activities {
                await activity.update(content)
            }
        }
    }

    static func stop() {
        lastUpdateAt = nil
        lastPublishedIsPaused = nil
        Task {
            await RecordingControlBridge.endAllLiveActivitiesImmediately()
        }
    }
}

enum LiveActivityFormatters {
    static func formatDuration(_ interval: TimeInterval) -> String {
        DateFormatters.formatDuration(interval)
    }

    static func formatDistance(_ meters: Double) -> String {
        DateFormatters.formatDistance(meters)
    }
}
