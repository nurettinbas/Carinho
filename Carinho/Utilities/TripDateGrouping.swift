import Foundation

enum TripDateSection: Int, CaseIterable, Identifiable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    case older

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .today: L10n.sectionToday
        case .yesterday: L10n.sectionYesterday
        case .thisWeek: L10n.sectionThisWeek
        case .thisMonth: L10n.sectionThisMonth
        case .older: L10n.sectionOlder
        }
    }
}

enum TripDateGrouping {
    static func section(for date: Date, calendar: Calendar = .current) -> TripDateSection {
        if calendar.isDateInToday(date) { return .today }
        if calendar.isDateInYesterday(date) { return .yesterday }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) { return .thisWeek }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .month) { return .thisMonth }
        return .older
    }

    static func groupedSections(
        from trips: [Trip],
        calendar: Calendar = .current
    ) -> [(section: TripDateSection, trips: [Trip])] {
        let grouped = Dictionary(grouping: trips) { trip in
            section(for: trip.startedAt, calendar: calendar)
        }

        return TripDateSection.allCases.compactMap { section in
            guard let sectionTrips = grouped[section], !sectionTrips.isEmpty else { return nil }
            let sorted = sectionTrips.sorted {
                $0.startedAt.timeIntervalSinceReferenceDate > $1.startedAt.timeIntervalSinceReferenceDate
            }
            return (section, sorted)
        }
    }
}
