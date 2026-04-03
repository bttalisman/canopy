import Foundation
import SwiftData

@Model
final class Stage {
    @Attribute(.unique) var id: UUID
    var name: String
    var mapX: Double
    var mapY: Double

    var event: Event?

    @Relationship(deleteRule: .cascade, inverse: \ScheduleItem.stage)
    var scheduleItems: [ScheduleItem] = []

    init(id: UUID? = nil, name: String, mapX: Double = 0, mapY: Double = 0) {
        self.id = id ?? UUID()
        self.name = name
        self.mapX = mapX
        self.mapY = mapY
    }
}
