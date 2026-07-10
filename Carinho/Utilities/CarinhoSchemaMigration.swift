import Foundation
import SwiftData

enum CarinhoSchemaV5: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(5, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self]
    }
}

enum CarinhoSchemaV6: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(6, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

enum CarinhoSchemaV7: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(7, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [Trip.self, TripPoint.self, SavedPlace.self, TripStop.self, UserCategory.self, MatchedRoutePoint.self, VehicleProfile.self]
    }
}

enum CarinhoMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [CarinhoSchemaV5.self, CarinhoSchemaV6.self, CarinhoSchemaV7.self]
    }

    static var stages: [MigrationStage] {
        [migrateV5toV6, migrateV6toV7]
    }

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: CarinhoSchemaV5.self,
        toVersion: CarinhoSchemaV6.self
    )

    static let migrateV6toV7 = MigrationStage.lightweight(
        fromVersion: CarinhoSchemaV6.self,
        toVersion: CarinhoSchemaV7.self
    )
}
