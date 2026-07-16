import Foundation

@MainActor
@Observable
final class TabSelection {
    static let shared = TabSelection()

    var selectedTab: AppTab = .trips

    func openPairing() {
        selectedTab = .pairing
    }

    func openTrips() {
        selectedTab = .trips
    }
}

enum AppTab: Hashable {
    case trips
    case stats
    case pairing
    case settings
    case devLog
}
