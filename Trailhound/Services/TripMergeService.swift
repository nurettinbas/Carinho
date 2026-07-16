import Foundation
import SwiftData

enum TripMergeService {
    @MainActor
    static func merge(trips: [Trip], into context: ModelContext) throws -> Trip? {
        let completed = trips.filter { $0.endedAt != nil }.sorted { $0.startedAt < $1.startedAt }
        guard completed.count >= 2 else { return nil }

        let first = completed.first!
        let last = completed.last!

        let merged = Trip(
            startedAt: first.startedAt,
            endedAt: last.endedAt
        )
        merged.categoryID = first.categoryID

        merged.startAddress = first.startAddress
        merged.startPlaceName = first.startPlaceName
        merged.endAddress = last.endAddress
        merged.endPlaceName = last.endPlaceName
        merged.note = mergedNotes(from: completed)
        merged.label = mergedLabels(from: completed)

        var sequence = 0
        var totalDistance = 0.0
        var maxSpeed: Double = 0

        for trip in completed {
            for point in trip.sortedPoints {
                let newPoint = TripPoint(
                    timestamp: point.timestamp,
                    latitude: point.latitude,
                    longitude: point.longitude,
                    sequence: sequence,
                    speedMps: point.speedMps,
                    trip: merged
                )
                sequence += 1
                merged.points.append(newPoint)
                context.insert(newPoint)
                if let speed = point.speedMps { maxSpeed = max(maxSpeed, speed) }
            }
            totalDistance += trip.distanceMeters
            for stop in trip.stops {
                let newStop = TripStop(
                    latitude: stop.latitude,
                    longitude: stop.longitude,
                    startedAt: stop.startedAt,
                    durationSeconds: stop.durationSeconds,
                    trip: merged
                )
                merged.stops.append(newStop)
                context.insert(newStop)
            }
            context.delete(trip)
        }

        merged.distanceMeters = totalDistance
        merged.maxSpeedMps = maxSpeed > 0 ? maxSpeed : nil
        merged.estimatedFuelCost = FuelCostCalculator.estimateCost(distanceMeters: totalDistance)
        merged.geocodeStatus = .pending
        context.insert(merged)
        try context.save()

        let mergedUUID = merged.id
        let container = context.container
        Task { @MainActor in
            await TripPostProcessor.process(
                tripUUID: mergedUUID,
                container: container
            )
        }

        return merged
    }

    private static func mergedNotes(from trips: [Trip]) -> String? {
        let notes = trips.compactMap(\.note).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !notes.isEmpty else { return nil }
        return notes.joined(separator: "\n\n")
    }

    private static func mergedLabels(from trips: [Trip]) -> String? {
        let labels = trips.compactMap(\.label).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let unique = Array(NSOrderedSet(array: labels)) as? [String] ?? labels
        guard !unique.isEmpty else { return nil }
        return unique.joined(separator: ", ")
    }
}
