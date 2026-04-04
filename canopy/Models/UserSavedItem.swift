import Foundation
import SwiftData

@Model
final class UserSavedItem {
    @Attribute(.unique) var id: UUID
    var savedAt: Date

    var scheduleItem: ScheduleItem?
    var event: Event?

    /// Save a schedule item (session-level bookmark)
    init(scheduleItem: ScheduleItem) {
        self.id = UUID()
        self.savedAt = Date()
        self.scheduleItem = scheduleItem
    }

    /// Save an event directly (event-level bookmark, no specific session)
    init(event: Event) {
        self.id = UUID()
        self.savedAt = Date()
        self.event = event
    }
}
