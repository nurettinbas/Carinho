import Foundation
import SwiftData

enum CategorySeeder {
    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserCategory>())) ?? []
        guard existing.isEmpty else { return }

        let defaults: [(UUID, String, String, Int)] = [
            (BuiltInCategory.personalID, L10n.categoryPersonal, "person.fill", 0),
            (BuiltInCategory.businessID, L10n.categoryBusiness, "briefcase.fill", 1)
        ]

        for (id, name, icon, order) in defaults {
            let category = UserCategory(id: id, name: name, systemImage: icon, isBuiltIn: true, sortOrder: order)
            context.insert(category)
        }
        try? context.save()
    }

    static func displayName(for categoryRaw: String, categories: [UserCategory]) -> String {
        if let match = categories.first(where: { $0.storageKey == categoryRaw || $0.id.uuidString == categoryRaw }) {
            return match.name
        }
        if let legacy = TripCategory(rawValue: categoryRaw) {
            return legacy.displayName
        }
        return categoryRaw
    }
}
