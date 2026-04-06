import Foundation
import SwiftData

actor TicketmasterService {
    static let shared = TicketmasterService()

    private let session = URLSession.shared

    // MARK: - Fetch Events (via backend proxy)

    func searchEvents(
        startDateTime: String? = nil
    ) async throws -> TMResponse {
        let baseURL = Secrets.canopyAPIBaseURL
        guard !baseURL.isEmpty, baseURL != "YOUR_API_URL_HERE" else {
            throw TicketmasterError.noAPIKey
        }

        var components = URLComponents(string: "\(baseURL)/api/events/ticketmaster/search")!
        var queryItems: [URLQueryItem] = []

        if let startDateTime {
            queryItems.append(URLQueryItem(name: "startDateTime", value: startDateTime))
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw TicketmasterError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TicketmasterError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let decoder = JSONDecoder()
            return try decoder.decode(TMResponse.self, from: data)
        case 401:
            throw TicketmasterError.invalidAPIKey
        case 429:
            throw TicketmasterError.rateLimited
        default:
            throw TicketmasterError.httpError(httpResponse.statusCode)
        }
    }

    // MARK: - Import into SwiftData

    @MainActor
    func importEvents(_ tmEvents: [TMEvent], into context: ModelContext) -> Int {
        var importedCount = 0

        for tmEvent in tmEvents {
            guard let startDate = tmEvent.startDate else { continue }

            // Check for duplicates by name + start date
            let name = tmEvent.name
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate {
                $0.name == name
            })

            let existing = (try? context.fetch(descriptor)) ?? []
            let isDuplicate = existing.contains { event in
                Calendar.current.isDate(event.startDate, inSameDayAs: startDate)
            }

            if isDuplicate { continue }

            // Skip if a curated event already covers this venue + date range
            let venueName = tmEvent.venue?.name ?? ""
            if !venueName.isEmpty {
                let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
                let coveredByCurated = allEvents.contains { curated in
                    curated.location.localizedCaseInsensitiveContains(venueName) &&
                    curated.startDate <= startDate &&
                    curated.endDate >= startDate &&
                    !curated.scheduleItems.isEmpty
                }
                if coveredByCurated { continue }
            }

            let endDate = tmEvent.endDate ?? Calendar.current.date(byAdding: .hour, value: 3, to: startDate)!

            let category = mapCategory(tmEvent.segmentName)

            let event = Event(
                name: tmEvent.name,
                slug: tmEvent.id,
                eventDescription: tmEvent.displayDescription,
                startDate: startDate,
                endDate: endDate,
                location: tmEvent.venue?.name ?? "Seattle",
                neighborhood: tmEvent.venue?.city?.name ?? "Seattle",
                logoSystemImage: category.systemImage,
                ticketingURL: tmEvent.url,
                category: category
            )

            // Store the image URL in the event description if we have one
            if let imageURL = tmEvent.primaryImage?.url,
               event.eventDescription.isEmpty {
                event.eventDescription = "Event at \(event.location)"
            }

            if let imageURL = tmEvent.primaryImage?.url {
                event.imageURL = imageURL
            }

            // Store venue coordinates
            if let loc = tmEvent.venue?.location {
                event.latitude = loc.latitudeDouble
                event.longitude = loc.longitudeDouble
            }

            context.insert(event)

            // Auto-create a schedule item so performer profiles work for single events
            let performerName = tmEvent.embedded?.attractions?.first?.name
            let performerURL = tmEvent.embedded?.attractions?.first?.url

            let scheduleItem = ScheduleItem(
                title: tmEvent.name,
                itemDescription: event.eventDescription,
                startTime: startDate,
                endTime: endDate,
                category: category == .concert ? "Music" : "General"
            )
            scheduleItem.performerName = performerName
            if let url = performerURL {
                scheduleItem.performerLinks = "[{\"label\":\"Tickets & Info\",\"url\":\"\(url)\"}]"
            }
            if let imageURL = tmEvent.primaryImage?.url {
                scheduleItem.performerImageURL = imageURL
            }
            scheduleItem.event = event
            context.insert(scheduleItem)

            // Auto-attach venue map data if we have it
            VenueMapData.attachMapData(to: event, using: context)

            importedCount += 1
        }

        return importedCount
    }

    private nonisolated func mapCategory(_ segment: String) -> EventCategory {
        switch segment.lowercased() {
        case "music": return .concert
        case "sports": return .community
        case "arts & theatre", "arts", "theatre": return .festival
        case "film": return .festival
        case "miscellaneous": return .community
        case "family": return .fair
        default: return .community
        }
    }
}

// MARK: - Errors

enum TicketmasterError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidAPIKey
    case rateLimited
    case httpError(Int)
    case noAPIKey

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid request URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidAPIKey:
            return "Invalid API key. Check your Ticketmaster API key in Settings."
        case .rateLimited:
            return "Rate limit exceeded. Try again later."
        case .httpError(let code):
            return "Server error (HTTP \(code))"
        case .noAPIKey:
            return "No API key configured. Add your Ticketmaster API key in Settings."
        }
    }
}
