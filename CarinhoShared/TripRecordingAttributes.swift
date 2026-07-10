import ActivityKit
import Foundation

struct TripRecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var elapsedSeconds: Int
        var distanceMeters: Double
        var currentSpeedKmh: Int
        var isPaused: Bool
    }

    var startedAt: Date
}
