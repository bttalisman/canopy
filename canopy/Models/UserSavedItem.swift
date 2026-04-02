import Foundation
import SwiftData

@Model
final class UserSavedItem {
    @Attribute(.unique) var id: UUID
    var savedAt: Date

    var scheduleItem: ScheduleItem?

    init(scheduleItem: ScheduleItem) {
        self.id = UUID()
        self.savedAt = Date()
        self.scheduleItem = scheduleItem
    }
}
