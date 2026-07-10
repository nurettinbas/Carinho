import Foundation

enum TripCategory: String, Codable, CaseIterable {
    case personal
    case business

    var displayName: String {
        switch self {
        case .personal: L10n.categoryPersonal
        case .business: L10n.categoryBusiness
        }
    }
}

enum GeocodeStatus: String, Codable {
    case pending
    case complete
    case failed
}

enum SavedPlaceKind: String, Codable, CaseIterable {
    case home
    case work
    case other

    var displayName: String {
        switch self {
        case .home: L10n.placeHome
        case .work: L10n.placeWork
        case .other: L10n.placeOther
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .work: "building.2.fill"
        case .other: "mappin.circle.fill"
        }
    }
}

enum VehicleFuelType: String, Codable, CaseIterable {
    case petrol
    case diesel
    case electric
    case hybrid

    var displayName: String {
        switch self {
        case .petrol: L10n.fuelPetrol
        case .diesel: L10n.fuelDiesel
        case .electric: L10n.fuelElectric
        case .hybrid: L10n.fuelHybrid
        }
    }
}

enum TripLabelOption: String, CaseIterable {
    case work = "İş"
    case market = "Market"
    case holiday = "Tatil"
    case other = "Diğer"

    var displayName: String {
        switch self {
        case .work: L10n.labelWork
        case .market: L10n.labelMarket
        case .holiday: L10n.labelHoliday
        case .other: L10n.labelOther
        }
    }
}
