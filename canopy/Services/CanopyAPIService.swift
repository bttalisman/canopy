import Foundation
import SwiftData

// MARK: - API Response Models

struct APIEvent: Codable, Identifiable {
    let id: String
    let name: String
    let slug: String
    let description: String?
    let startDate: String
    let endDate: String
    let location: String
    let neighborhood: String?
    let logoSystemImage: String?
    let imageURL: String?
    let mapImageURL: String?
    let mapPinSize: Double?
    let ticketingURL: String?
    let latitude: Double?
    let longitude: Double?
    let category: String?
    let permitId: String?
    let isAccessible: Bool?
    let isFree: Bool?
    let isCityOfficial: Bool?
    let stages: [APIStage]?
    let scheduleItems: [APIScheduleItem]?
    let mapPins: [APIMapPin]?
}

struct APIStage: Codable {
    let id: String
    let name: String
    let mapX: Double?
    let mapY: Double?
}

struct APIScheduleItem: Codable {
    let id: String
    let stageId: String?
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let category: String?
    let isCancelled: Bool?
    let performerName: String?
    let performerBio: String?
    let performerImageURL: String?
    let performerLinks: String?
}

struct APIMapPin: Codable {
    let id: String
    let label: String
    let pinType: String?
    let x: Double
    let y: Double
    let latitude: Double?
    let longitude: Double?
    let description: String?
}

// MARK: - Service

actor CanopyAPIService {
    static let shared = CanopyAPIService()

    private let session = URLSession.shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    var baseURL: String {
        Secrets.canopyAPIBaseURL
    }

    func fetchEvents() async throws -> [APIEvent] {
        guard !baseURL.isEmpty && baseURL != "YOUR_API_URL_HERE" else {
            throw CanopyAPIError.notConfigured
        }

        guard let url = URL(string: "\(baseURL)/api/events") else {
            throw CanopyAPIError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CanopyAPIError.serverError
        }

        return try decoder.decode([APIEvent].self, from: data)
    }

    // MARK: - Import into SwiftData

    @MainActor
    func importEvents(_ apiEvents: [APIEvent], into context: ModelContext) -> Int {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let fallbackFormatter = ISO8601DateFormatter()

        func parseDate(_ str: String) -> Date? {
            isoFormatter.date(from: str) ?? fallbackFormatter.date(from: str)
        }

        var importedCount = 0

        for apiEvent in apiEvents {
            guard let startDate = parseDate(apiEvent.startDate),
                  let endDate = parseDate(apiEvent.endDate) else { continue }

            // Check for duplicates by slug
            let slug = apiEvent.slug
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate {
                $0.slug == slug
            })

            let existing = (try? context.fetch(descriptor)) ?? []
            if !existing.isEmpty {
                if let event = existing.first {
                    // Update event-level fields from backend
                    event.name = apiEvent.name
                    event.eventDescription = apiEvent.description ?? event.eventDescription
                    event.startDate = startDate
                    event.endDate = endDate
                    event.location = apiEvent.location
                    event.neighborhood = apiEvent.neighborhood ?? event.neighborhood
                    event.logoSystemImage = apiEvent.logoSystemImage ?? event.logoSystemImage
                    event.imageURL = apiEvent.imageURL
                    event.mapImageURL = apiEvent.mapImageURL
                    event.mapPinSize = apiEvent.mapPinSize ?? event.mapPinSize
                    event.ticketingURL = apiEvent.ticketingURL
                    event.latitude = apiEvent.latitude ?? event.latitude
                    event.longitude = apiEvent.longitude ?? event.longitude
                    event.category = mapCategory(apiEvent.category ?? event.category.rawValue)
                    event.permitId = apiEvent.permitId
                    event.isAccessible = apiEvent.isAccessible
                    event.isFree = apiEvent.isFree
                    event.isCityOfficial = apiEvent.isCityOfficial

                    updateScheduleItems(for: event, from: apiEvent, parseDate: parseDate, context: context)
                    updateMapPins(for: event, from: apiEvent, context: context)
                    updateStages(for: event, from: apiEvent, context: context)
                    try? context.save()
                }
                continue
            }

            let category = mapCategory(apiEvent.category ?? "community")

            let event = Event(
                id: UUID(uuidString: apiEvent.id),
                name: apiEvent.name,
                slug: apiEvent.slug,
                eventDescription: apiEvent.description ?? "",
                startDate: startDate,
                endDate: endDate,
                location: apiEvent.location,
                neighborhood: apiEvent.neighborhood ?? "",
                logoSystemImage: apiEvent.logoSystemImage ?? category.systemImage,
                ticketingURL: apiEvent.ticketingURL,
                category: category
            )
            event.imageURL = apiEvent.imageURL
            event.mapImageURL = apiEvent.mapImageURL
            event.mapPinSize = apiEvent.mapPinSize
            event.latitude = apiEvent.latitude
            event.longitude = apiEvent.longitude
            event.permitId = apiEvent.permitId
            event.isAccessible = apiEvent.isAccessible
            event.isFree = apiEvent.isFree
            event.isCityOfficial = apiEvent.isCityOfficial

            context.insert(event)

            // Add stages
            var stageMap: [String: Stage] = [:]
            for apiStage in apiEvent.stages ?? [] {
                let stage = Stage(id: UUID(uuidString: apiStage.id), name: apiStage.name, mapX: apiStage.mapX ?? 0, mapY: apiStage.mapY ?? 0)
                stage.event = event
                context.insert(stage)
                stageMap[apiStage.id] = stage
            }

            // Add schedule items
            for apiItem in apiEvent.scheduleItems ?? [] {
                guard let start = parseDate(apiItem.startTime),
                      let end = parseDate(apiItem.endTime) else { continue }

                let item = ScheduleItem(
                    id: UUID(uuidString: apiItem.id),
                    title: apiItem.title,
                    itemDescription: apiItem.description ?? "",
                    startTime: start,
                    endTime: end,
                    category: apiItem.category ?? "General",
                    isCancelled: apiItem.isCancelled ?? false
                )
                item.performerName = apiItem.performerName
                item.performerBio = apiItem.performerBio
                item.performerImageURL = apiItem.performerImageURL
                item.performerLinks = apiItem.performerLinks
                item.event = event
                if let stageId = apiItem.stageId {
                    item.stage = stageMap[stageId]
                }
                context.insert(item)
            }

            // Add map pins
            for apiPin in apiEvent.mapPins ?? [] {
                let pin = MapPin(
                    label: apiPin.label,
                    pinType: MapPinType(rawValue: apiPin.pinType ?? "Custom") ?? .custom,
                    x: apiPin.x,
                    y: apiPin.y,
                    latitude: apiPin.latitude,
                    longitude: apiPin.longitude,
                    pinDescription: apiPin.description ?? ""
                )
                pin.event = event
                context.insert(pin)
            }

            // Also attach local venue map data if API didn't provide pins or custom map
            if (apiEvent.mapPins ?? []).isEmpty && apiEvent.mapImageURL == nil {
                VenueMapData.attachMapData(to: event, using: context)
            }

            importedCount += 1
        }

        return importedCount
    }

    @MainActor
    private func updateScheduleItems(for event: Event, from apiEvent: APIEvent, parseDate: (String) -> Date?, context: ModelContext) {
        guard let apiItems = apiEvent.scheduleItems, !apiItems.isEmpty else { return }

        // Build a set of existing schedule item titles + times to avoid duplicates
        let existingKeys = Set(event.scheduleItems.map { "\($0.title)|\($0.startTime.timeIntervalSince1970)" })

        for apiItem in apiItems {
            guard let start = parseDate(apiItem.startTime),
                  let end = parseDate(apiItem.endTime) else { continue }

            let key = "\(apiItem.title)|\(start.timeIntervalSince1970)"
            if existingKeys.contains(key) { continue }

            let item = ScheduleItem(
                id: UUID(uuidString: apiItem.id),
                title: apiItem.title,
                itemDescription: apiItem.description ?? "",
                startTime: start,
                endTime: end,
                category: apiItem.category ?? "General",
                isCancelled: apiItem.isCancelled ?? false
            )
            item.performerName = apiItem.performerName
            item.performerBio = apiItem.performerBio
            item.performerImageURL = apiItem.performerImageURL
            item.performerLinks = apiItem.performerLinks
            item.event = event
            context.insert(item)
        }
    }

    @MainActor
    private func updateMapPins(for event: Event, from apiEvent: APIEvent, context: ModelContext) {
        // nil means the API response didn't include the field — leave local alone.
        // An empty array means "no pins" and should clear any stale local pins.
        guard let apiPins = apiEvent.mapPins else { return }

        // Full reconcile: delete every existing pin for this event, then
        // insert fresh copies of whatever the server currently has. The
        // server is the source of truth; trying to match by label was
        // unreliable (labels can change or repeat) and silently dropped pins
        // added in the admin Map Editor after the event was first imported.
        for existing in event.mapPins {
            context.delete(existing)
        }

        for apiPin in apiPins {
            let pin = MapPin(
                label: apiPin.label,
                pinType: MapPinType(rawValue: apiPin.pinType ?? "Custom") ?? .custom,
                x: apiPin.x,
                y: apiPin.y,
                latitude: apiPin.latitude,
                longitude: apiPin.longitude,
                pinDescription: apiPin.description ?? ""
            )
            pin.event = event
            context.insert(pin)
        }
    }

    @MainActor
    private func updateStages(for event: Event, from apiEvent: APIEvent, context: ModelContext) {
        guard let apiStages = apiEvent.stages, !apiStages.isEmpty else { return }

        let existingNames = Set(event.stages.map(\.name))

        for apiStage in apiStages {
            if existingNames.contains(apiStage.name) { continue }

            let stage = Stage(id: UUID(uuidString: apiStage.id), name: apiStage.name, mapX: apiStage.mapX ?? 0, mapY: apiStage.mapY ?? 0)
            stage.event = event
            context.insert(stage)
        }
    }

    private nonisolated func mapCategory(_ str: String) -> EventCategory {
        EventCategory(rawValue: str.capitalized) ?? .community
    }
}

enum CanopyAPIError: LocalizedError {
    case notConfigured
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .notConfigured: return "Backend API not configured."
        case .invalidURL: return "Invalid API URL."
        case .serverError: return "Server error. Try again later."
        }
    }
}
