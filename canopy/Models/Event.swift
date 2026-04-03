import Foundation
import SwiftData

@Model
final class Event {
    @Attribute(.unique) var id: UUID
    var name: String
    var slug: String
    var eventDescription: String
    var startDate: Date
    var endDate: Date
    var location: String
    var neighborhood: String
    var logoSystemImage: String
    var ticketingURL: String?
    var imageURL: String?
    var latitude: Double?
    var longitude: Double?
    var isActive: Bool
    var category: EventCategory

    @Relationship(deleteRule: .cascade, inverse: \Stage.event)
    var stages: [Stage] = []

    @Relationship(deleteRule: .cascade, inverse: \ScheduleItem.event)
    var scheduleItems: [ScheduleItem] = []

    @Relationship(deleteRule: .cascade, inverse: \MapPin.event)
    var mapPins: [MapPin] = []

    init(
        name: String,
        slug: String,
        eventDescription: String,
        startDate: Date,
        endDate: Date,
        location: String,
        neighborhood: String,
        logoSystemImage: String = "party.popper",
        ticketingURL: String? = nil,
        isActive: Bool = true,
        category: EventCategory = .festival
    ) {
        self.id = UUID()
        self.name = name
        self.slug = slug
        self.eventDescription = eventDescription
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.neighborhood = neighborhood
        self.logoSystemImage = logoSystemImage
        self.ticketingURL = ticketingURL
        self.isActive = isActive
        self.category = category
    }
}

enum EventCategory: String, Codable, CaseIterable, Identifiable {
    case festival = "Festival"
    case fair = "Fair"
    case conference = "Conference"
    case expo = "Expo"
    case concert = "Concert"
    case community = "Community"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .festival: return "party.popper"
        case .fair: return "tent.2.fill"
        case .conference: return "person.3.fill"
        case .expo: return "building.2.fill"
        case .concert: return "music.note"
        case .community: return "heart.fill"
        }
    }
}
