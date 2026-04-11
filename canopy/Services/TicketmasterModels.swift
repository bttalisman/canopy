import Foundation

// MARK: - Top-level Response

struct TMResponse: Codable, Sendable {
    let embedded: TMEmbeddedEvents?
    let page: TMPage?

    enum CodingKeys: String, CodingKey {
        case embedded = "_embedded"
        case page
    }
}

struct TMEmbeddedEvents: Codable, Sendable {
    let events: [TMEvent]
}

struct TMPage: Codable, Sendable {
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let number: Int
}

// MARK: - Event

struct TMEvent: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let url: String?
    let description: String?
    let info: String?
    let pleaseNote: String?
    let images: [TMImage]?
    let dates: TMDates?
    let classifications: [TMClassification]?
    let priceRanges: [TMPriceRange]?
    let embedded: TMEventEmbedded?

    enum CodingKeys: String, CodingKey {
        case id, name, url, description, info, pleaseNote
        case images, dates, classifications, priceRanges
        case embedded = "_embedded"
    }

    var displayDescription: String {
        description ?? info ?? pleaseNote ?? ""
    }

    var ticketURL: URL? {
        guard let url else { return nil }
        return URL(string: url)
    }

    var primaryImage: TMImage? {
        // Prefer largest 16:9 ratio, non-fallback
        let candidates = images?.filter { $0.fallback != true } ?? images ?? []
        let wideImages = candidates.filter { $0.ratio == "16_9" }
        let best = wideImages.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })
        return best ?? candidates.max(by: { ($0.width ?? 0) < ($1.width ?? 0) })
    }

    var venue: TMVenue? {
        embedded?.venues?.first
    }

    var primaryClassification: TMClassification? {
        classifications?.first(where: { $0.primary == true }) ?? classifications?.first
    }

    var segmentName: String {
        primaryClassification?.segment?.name ?? "Event"
    }

    var genreName: String? {
        primaryClassification?.genre?.name
    }

    var startDate: Date? {
        guard let dateStr = dates?.start?.dateTime else {
            // Fall back to localDate
            guard let localDate = dates?.start?.localDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: localDate)
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateStr)
    }

    var endDate: Date? {
        guard let dateStr = dates?.end?.dateTime else {
            guard let localDate = dates?.end?.localDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: localDate)
        }
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: dateStr)
    }

    var isCancelled: Bool {
        dates?.status?.code == "cancelled" || dates?.status?.code == "canceled"
    }
}

// MARK: - Dates

struct TMDates: Codable, Sendable {
    let start: TMDateStart?
    let end: TMDateEnd?
    let timezone: String?
    let status: TMDateStatus?
    let spanMultipleDays: Bool?
}

struct TMDateStart: Codable, Sendable {
    let localDate: String?
    let localTime: String?
    let dateTime: String?
    let dateTBD: Bool?
    let dateTBA: Bool?
    let timeTBA: Bool?
    let noSpecificTime: Bool?
}

struct TMDateEnd: Codable, Sendable {
    let localDate: String?
    let localTime: String?
    let dateTime: String?
    let approximate: Bool?
    let noSpecificTime: Bool?
}

struct TMDateStatus: Codable, Sendable {
    let code: String?
}

// MARK: - Image

struct TMImage: Codable, Sendable {
    let url: String
    let ratio: String?
    let width: Int?
    let height: Int?
    let fallback: Bool?
}

// MARK: - Classification

struct TMClassification: Codable, Sendable {
    let primary: Bool?
    let family: Bool?
    let segment: TMNamedEntity?
    let genre: TMNamedEntity?
    let subGenre: TMNamedEntity?
}

struct TMNamedEntity: Codable, Sendable {
    let id: String?
    let name: String?
}

// MARK: - Price Range

struct TMPriceRange: Codable, Sendable {
    let type: String?
    let currency: String?
    let min: Double?
    let max: Double?
}

// MARK: - Venue (embedded in event)

struct TMEventEmbedded: Codable, Sendable {
    let venues: [TMVenue]?
    let attractions: [TMAttraction]?
}

struct TMVenue: Codable, Sendable {
    let id: String?
    let name: String?
    let url: String?
    let address: TMAddress?
    let city: TMCity?
    let state: TMState?
    let country: TMCountry?
    let location: TMLocation?
    let postalCode: String?

    var displayAddress: String {
        [address?.line1, city?.name, state?.stateCode]
            .compactMap { $0 }
            .joined(separator: ", ")
    }
}

struct TMAddress: Codable, Sendable {
    let line1: String?
    let line2: String?
}

struct TMCity: Codable, Sendable {
    let name: String?
}

struct TMState: Codable, Sendable {
    let stateCode: String?
    let name: String?
}

struct TMCountry: Codable, Sendable {
    let countryCode: String?
    let name: String?
}

struct TMLocation: Codable, Sendable {
    let longitude: String?
    let latitude: String?

    var latitudeDouble: Double? {
        guard let latitude else { return nil }
        return Double(latitude)
    }

    var longitudeDouble: Double? {
        guard let longitude else { return nil }
        return Double(longitude)
    }
}

struct TMAttraction: Codable, Sendable {
    let id: String?
    let name: String?
    let url: String?
}
