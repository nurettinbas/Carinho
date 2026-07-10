import CoreLocation
import Foundation
import SwiftData

struct DailyDistance: Identifiable {
    let id: Date
    let day: Date
    let distanceMeters: Double

    var distanceKilometers: Double { distanceMeters / 1000 }
}

struct CategoryDistance: Identifiable {
    let id: String
    let name: String
    let distanceMeters: Double

    var distanceKilometers: Double { distanceMeters / 1000 }
}

enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: L10n.string("stats.period.week")
        case .month: L10n.string("stats.period.month")
        case .custom: L10n.string("stats.period.custom")
        }
    }
}

struct StatsViewModel {
    static func stats(for trips: [Trip], categoryID: String? = nil) -> TripStats {
        let completed = trips.filter { trip in
            guard trip.endedAt != nil else { return false }
            if let categoryID { return trip.categoryID == categoryID }
            return true
        }

        let totalDistance = completed.reduce(0) { $0 + $1.distanceMeters }
        let totalDuration = completed.compactMap(\.duration).reduce(0, +)
        let totalFuel = completed.reduce(0) { partial, trip in
            partial + fuelCost(for: trip)
        }
        let count = completed.count
        let averageDuration = count > 0 ? totalDuration / Double(count) : 0
        let nightRatio = nightDrivingRatio(for: completed)

        return TripStats(
            tripCount: count,
            totalDistanceMeters: totalDistance,
            averageDuration: averageDuration,
            estimatedFuelCost: totalFuel,
            nightDrivingRatio: nightRatio
        )
    }

    static func fuelCost(for trip: Trip) -> Double {
        if let cost = trip.estimatedFuelCost, cost > 0 {
            return cost
        }
        guard trip.distanceMeters > 0 else { return 0 }
        return FuelCostCalculator.estimateCost(for: trip)
    }

    static func trips(in interval: DateInterval, from trips: [Trip]) -> [Trip] {
        trips.filter { trip in
            guard let endedAt = trip.endedAt else { return false }
            return interval.contains(trip.startedAt) || interval.contains(endedAt)
        }
    }

    static func interval(for period: StatsPeriod, customStart: Date, customEnd: Date) -> DateInterval {
        let calendar = Calendar.current
        let end = Date()
        switch period {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .custom:
            let start = min(customStart, customEnd)
            let finish = max(customStart, customEnd)
            return DateInterval(start: start, end: finish)
        }
    }

    static func previousInterval(for interval: DateInterval) -> DateInterval {
        let duration = interval.duration
        let start = interval.start.addingTimeInterval(-duration)
        return DateInterval(start: start, end: interval.start)
    }

    static func trendPercent(current: Double, previous: Double) -> Double? {
        guard previous > 0 else { return current > 0 ? 100 : nil }
        return ((current - previous) / previous) * 100
    }

    static func trendText(current: Double, previous: Double) -> String? {
        guard let percent = trendPercent(current: current, previous: previous) else { return nil }
        let format = L10n.string("stats.trend.format")
        let sign = percent > 0 ? "+" : ""
        return String(format: format, sign, Int(percent.rounded()))
    }

    static func dailyDistances(in interval: DateInterval, from trips: [Trip]) -> [DailyDistance] {
        let calendar = Calendar.current
        let filtered = Self.trips(in: interval, from: trips)
        var buckets: [Date: Double] = [:]

        var day = calendar.startOfDay(for: interval.start)
        let endDay = calendar.startOfDay(for: interval.end)
        while day <= endDay {
            buckets[day] = 0
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }

        for trip in filtered {
            let tripDay = calendar.startOfDay(for: trip.startedAt)
            buckets[tripDay, default: 0] += trip.distanceMeters
        }

        return buckets.keys.sorted().map { day in
            DailyDistance(id: day, day: day, distanceMeters: buckets[day] ?? 0)
        }
    }

    static func categoryBreakdown(for trips: [Trip], categories: [UserCategory]) -> [CategoryDistance] {
        let filtered = trips.filter { $0.endedAt != nil }
        var totals: [String: Double] = [:]

        for trip in filtered {
            totals[trip.categoryID, default: 0] += trip.distanceMeters
        }

        return totals.map { key, distance in
            let name = categories.first(where: { $0.storageKey == key })?.name
                ?? TripCategory(rawValue: key)?.displayName
                ?? L10n.string("label.other")
            return CategoryDistance(id: key, name: name, distanceMeters: distance)
        }
        .sorted { $0.distanceMeters > $1.distanceMeters }
    }

    static func nightDrivingRatio(for trips: [Trip]) -> Double {
        var nightMeters = 0.0
        var totalMeters = 0.0
        let calendar = Calendar.current

        for trip in trips {
            let points = trip.sortedPoints
            guard points.count >= 2 else { continue }

            for index in 1..<points.count {
                let previous = points[index - 1]
                let current = points[index]
                let segment = previous.location.distance(from: current.location)
                guard segment > 0 else { continue }

                let midpoint = previous.timestamp.addingTimeInterval(
                    current.timestamp.timeIntervalSince(previous.timestamp) / 2
                )
                totalMeters += segment
                if isNightHour(midpoint, calendar: calendar) {
                    nightMeters += segment
                }
            }
        }

        guard totalMeters > 0 else { return 0 }
        return nightMeters / totalMeters
    }

    static func nightDrivingPercentText(for ratio: Double) -> String {
        let percent = Int((ratio * 100).rounded())
        let format = L10n.string("stats.night_driving.format")
        return String(format: format, percent)
    }

    private static func isNightHour(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        return hour >= 22 || hour < 6
    }
}

struct TripStats {
    let tripCount: Int
    let totalDistanceMeters: Double
    let averageDuration: TimeInterval
    let estimatedFuelCost: Double
    let nightDrivingRatio: Double

    init(
        tripCount: Int,
        totalDistanceMeters: Double,
        averageDuration: TimeInterval,
        estimatedFuelCost: Double,
        nightDrivingRatio: Double = 0
    ) {
        self.tripCount = tripCount
        self.totalDistanceMeters = totalDistanceMeters
        self.averageDuration = averageDuration
        self.estimatedFuelCost = estimatedFuelCost
        self.nightDrivingRatio = nightDrivingRatio
    }

    var totalDistanceText: String { DateFormatters.formatDistance(totalDistanceMeters) }
    var averageDurationText: String { DateFormatters.formatDuration(averageDuration) }
    var fuelCostText: String { FuelCostCalculator.formatCost(estimatedFuelCost) }
    var nightDrivingText: String { StatsViewModel.nightDrivingPercentText(for: nightDrivingRatio) }
}
