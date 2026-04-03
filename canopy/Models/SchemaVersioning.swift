import Foundation
import SwiftData

enum CanopySchemaV1: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    nonisolated static var models: [any PersistentModel.Type] {
        [Event.self, Stage.self, ScheduleItem.self, MapPin.self, UserSavedItem.self]
    }
}

enum CanopyMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [CanopySchemaV1.self]
    }

    nonisolated static var stages: [MigrationStage] {
        // No migrations yet — this is the initial version.
        // When the schema changes, add a new CanopySchemaV2 and a migration stage here.
        []
    }
}
