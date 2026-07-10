import Foundation
import SwiftData

enum TripRecoveryService {
    static let staleThreshold: TimeInterval = 24 * 60 * 60

    struct OrphanTrip: Identifiable {
        let id: UUID
        let trip: Trip
        let lastActivity: Date
        let isStale: Bool
    }

    @MainActor
    static func findOrphanTrips(in context: ModelContext) -> [OrphanTrip] {
        var results: [OrphanTrip] = []
        results.reserveCapacity(4)

        for trip in TripFetch.orphansNewestFirst(from: context) {
            let lastPoint = trip.sortedPoints.last?.timestamp ?? trip.startedAt
            let lastActivity = max(lastPoint, trip.startedAt)
            let isStale = Date().timeIntervalSince(lastActivity) >= staleThreshold
            results.append(
                OrphanTrip(id: trip.id, trip: trip, lastActivity: lastActivity, isStale: isStale)
            )
        }

        return results
    }

    @MainActor
    static func scheduleOrphanStaleNotifications(
        in context: ModelContext,
        excludingTripID: UUID? = nil
    ) {
        for orphan in findOrphanTrips(in: context) where !orphan.isStale && orphan.id != excludingTripID {
            TripNotificationService.scheduleOrphanStaleNotification(
                tripID: orphan.id,
                lastActivity: orphan.lastActivity
            )
        }
    }

    @MainActor
    static func finalizeStaleOrphans(in context: ModelContext) {
        for orphan in findOrphanTrips(in: context) where orphan.isStale {
            TripNotificationService.cancelOrphanStaleNotification(tripID: orphan.id)
            finalizeOrphan(orphan.trip, in: context, saveTrip: true)
        }
    }

    @MainActor
    static func finalizeOrphan(_ trip: Trip, in context: ModelContext, saveTrip: Bool) {
        TripNotificationService.cancelOrphanStaleNotification(tripID: trip.id)
        trip.endedAt = trip.sortedPoints.last?.timestamp ?? Date()
        if !saveTrip {
            context.delete(trip)
        }
        try? context.save()
    }

    @MainActor
    static func deleteOrphan(_ trip: Trip, in context: ModelContext) {
        TripNotificationService.cancelOrphanStaleNotification(tripID: trip.id)
        context.delete(trip)
        try? context.save()
    }

    @MainActor
    static func resumeOrphan(_ trip: Trip, recordingService: TripRecordingService) {
        TripNotificationService.cancelOrphanStaleNotification(tripID: trip.id)
        recordingService.resumeRecording(trip: trip)
    }
}
