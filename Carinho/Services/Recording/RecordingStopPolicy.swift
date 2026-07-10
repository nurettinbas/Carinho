import Foundation
import SwiftData

enum RecordingStopPolicy {
    enum StopReason {
        case manual, automatic, carPlay, bluetooth, idle
    }

    static func shouldSaveTrip(
        saveTrip: Bool,
        reason: StopReason,
        duration: TimeInterval,
        distanceMeters: Double,
        minimumDurationSeconds: TimeInterval,
        minimumDistanceMeters: Double
    ) -> Bool {
        guard saveTrip else { return false }
        if reason == .manual { return true }
        return duration >= minimumDurationSeconds && distanceMeters >= minimumDistanceMeters
    }

    static func shouldApplyIdleAutoStop(activeTriggerIsManual: Bool) -> Bool {
        !activeTriggerIsManual
    }
}
