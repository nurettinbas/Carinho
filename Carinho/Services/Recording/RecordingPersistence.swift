import Foundation
import SwiftData

enum RecordingPersistence {
    @MainActor
    static func save(context: ModelContext) throws {
        try context.save()
    }

    @MainActor
    static func saveOrPresentError(context: ModelContext) {
        do {
            try context.save()
        } catch {
            AppErrorPresenter.shared.present(error.localizedDescription)
        }
    }
}
