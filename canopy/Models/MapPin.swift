import Foundation
import SwiftData

@Model
final class MapPin {
    @Attribute(.unique) var id: UUID
    var label: String
    var pinType: MapPinType
    var x: Double
    var y: Double
    var latitude: Double?
    var longitude: Double?
    var pinDescription: String

    var event: Event?

    init(
        label: String,
        pinType: MapPinType = .custom,
        x: Double,
        y: Double,
        latitude: Double? = nil,
        longitude: Double? = nil,
        pinDescription: String = ""
    ) {
        self.id = UUID()
        self.label = label
        self.pinType = pinType
        self.x = x
        self.y = y
        self.latitude = latitude
        self.longitude = longitude
        self.pinDescription = pinDescription
    }
}

enum MapPinType: String, Codable, CaseIterable, Identifiable {
    case restroom = "Restroom"
    case food = "Food"
    case stage = "Stage"
    case firstAid = "First Aid"
    case exit = "Exit"
    case wifi = "WiFi"
    case accessible = "Accessible"
    case atm = "ATM"
    case parking = "Parking"
    case info = "Info"
    case giftShop = "Gift Shop"
    case bus = "Bus"
    case custom = "Custom"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .restroom: return "toilet.fill"
        case .food: return "fork.knife"
        case .stage: return "music.mic"
        case .firstAid: return "cross.case.fill"
        case .exit: return "arrow.right.square"
        case .wifi: return "wifi"
        case .accessible: return "figure.roll"
        case .atm: return "banknote"
        case .parking: return "car.fill"
        case .info: return "info.circle.fill"
        case .giftShop: return "bag.fill"
        case .bus: return "bus.fill"
        case .custom: return "mappin"
        }
    }

    var color: String {
        switch self {
        case .restroom: return "blue"
        case .food: return "orange"
        case .stage: return "purple"
        case .firstAid: return "red"
        case .exit: return "green"
        case .wifi: return "cyan"
        case .accessible: return "indigo"
        case .atm: return "yellow"
        case .parking: return "blue"
        case .info: return "teal"
        case .giftShop: return "pink"
        case .bus: return "green"
        case .custom: return "gray"
        }
    }
}
