import Foundation
import SwiftData

enum CarinhoSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self]
    }
}

/// Legacy in-memory / test schema before connection fields on vehicles.
enum CarinhoSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

enum CarinhoSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(8, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

/// Schema history used by in-memory migration tests.
/// Do not pass `CarinhoMigrationPlan` to a runtime disk `ModelContainer` — SwiftData aborts with
/// "Duplicate version checksums detected" when multiple enums reference the same live `@Model` types.
enum CarinhoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CarinhoSchemaV5.self, CarinhoSchemaV7.self]
    }

    static var stages: [MigrationStage] {
        [migrateV5toV7]
    }

    static let migrateV5toV7 = MigrationStage.lightweight(
        fromVersion: CarinhoSchemaV5.self,
        toVersion: CarinhoSchemaV7.self
    )
}
