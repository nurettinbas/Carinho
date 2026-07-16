import Foundation
import SwiftData

enum TrailhoundSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self]
    }
}

/// Legacy in-memory / test schema before connection fields on vehicles.
enum TrailhoundSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

enum TrailhoundSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(8, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

/// Schema history used by in-memory migration tests.
/// Do not pass `TrailhoundMigrationPlan` to a runtime disk `ModelContainer` — SwiftData aborts with
/// "Duplicate version checksums detected" when multiple enums reference the same live `@Model` types.
enum TrailhoundMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TrailhoundSchemaV5.self, TrailhoundSchemaV7.self]
    }

    static var stages: [MigrationStage] {
        [migrateV5toV7]
    }

    static let migrateV5toV7 = MigrationStage.lightweight(
        fromVersion: TrailhoundSchemaV5.self,
        toVersion: TrailhoundSchemaV7.self
    )
}
