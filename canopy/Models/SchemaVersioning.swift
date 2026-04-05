import Foundation
import SwiftData

enum CanopySchemaV1: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    nonisolated static var models: [any PersistentModel.Type] {
        [Event.self, Stage.self, ScheduleItem.self, MapPin.self, UserSavedItem.self]
    }
}

enum CanopySchemaV2: VersionedSchema {
    nonisolated static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    nonisolated static var models: [any PersistentModel.Type] {
        [Event.self, Stage.self, ScheduleItem.self, MapPin.self, UserSavedItem.self]
    }
}

enum CanopyMigrationPlan: SchemaMigrationPlan {
    nonisolated static var schemas: [any VersionedSchema.Type] {
        [CanopySchemaV1.self, CanopySchemaV2.self]
    }

    nonisolated static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // Lightweight migration: SwiftData handles adding new optional properties automatically.
    // ScheduleItem gained: performerName, performerBio, performerImageURL, performerLinks
    // UserSavedItem gained: event (optional relationship)
    // Event, Stage gained: optional id parameter (no schema change)
    nonisolated static var migrateV1toV2: MigrationStage {
        .lightweight(fromVersion: CanopySchemaV1.self, toVersion: CanopySchemaV2.self)
    }
}
