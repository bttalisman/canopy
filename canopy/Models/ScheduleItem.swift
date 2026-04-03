import Foundation
import SwiftData

@Model
final class ScheduleItem {
    @Attribute(.unique) var id: UUID
    var title: String
    var itemDescription: String
    var startTime: Date
    var endTime: Date
    var category: String
    var isCancelled: Bool

    var event: Event?
    var stage: Stage?

    @Relationship(deleteRule: .cascade, inverse: \UserSavedItem.scheduleItem)
    var savedByUsers: [UserSavedItem] = []

    var isSaved: Bool {
        !savedByUsers.isEmpty
    }

    init(
        id: UUID? = nil,
        title: String,
        itemDescription: String = "",
        startTime: Date,
        endTime: Date,
        category: String = "General",
        isCancelled: Bool = false
    ) {
        self.id = id ?? UUID()
        self.title = title
        self.itemDescription = itemDescription
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
        self.isCancelled = isCancelled
    }
}
