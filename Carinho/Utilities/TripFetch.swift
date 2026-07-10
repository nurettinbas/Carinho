import Foundation
import SwiftData

/// Fetches trips without SwiftData `#Predicate` or `SortDescriptor` key paths (Swift 6 Sendable-safe).
@MainActor
enum TripFetch {
    static func all(from context: ModelContext) -> [Trip] {
        (try? context.fetch(FetchDescriptor<Trip>())) ?? []
    }

    static func completed(from context: ModelContext) -> [Trip] {
        all(from: context).filter { $0.endedAt != nil }
    }

    static func completedSince(_ date: Date, from context: ModelContext) -> [Trip] {
        let minimum = date.timeIntervalSinceReferenceDate
        return completed(from: context).filter {
            $0.startedAt.timeIntervalSinceReferenceDate >= minimum
        }
    }

    static func completedBefore(_ date: Date, from context: ModelContext) -> [Trip] {
        let maximum = date.timeIntervalSinceReferenceDate
        return completed(from: context).filter {
            $0.startedAt.timeIntervalSinceReferenceDate < maximum
        }
    }

    static func orphans(from context: ModelContext) -> [Trip] {
        all(from: context).filter { $0.endedAt == nil }
    }

    static func orphansNewestFirst(from context: ModelContext) -> [Trip] {
        var trips = orphans(from: context)
        trips.sort { lhs, rhs in
            lhs.startedAt.timeIntervalSinceReferenceDate > rhs.startedAt.timeIntervalSinceReferenceDate
        }
        return trips
    }

    static func syncWidgetWeekDistance(in context: ModelContext) {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weekTrips = StatsViewModel.trips(
            in: DateInterval(start: weekAgo, end: Date()),
            from: completedSince(weekAgo, from: context)
        )
        let stats = StatsViewModel.stats(for: weekTrips)
        let defaults = UserDefaults(suiteName: "group.com.carinho.app")
        defaults?.set(stats.totalDistanceMeters, forKey: "stats.weekDistance")

        let startOfDay = Calendar.current.startOfDay(for: Date())
        let todayTrips = completedSince(startOfDay, from: context)
        let todayDistance = todayTrips.reduce(0) { $0 + $1.distanceMeters }
        TodayKmProvider.syncTodayDistance(todayDistance)
    }
}
