import Foundation
import SwiftData

actor TicketmasterService {
    static let shared = TicketmasterService()

    private let baseURL = "https://app.ticketmaster.com/discovery/v2"
    private let session = URLSession.shared

    // MARK: - Fetch Events

    func searchEvents(
        apiKey: String,
        city: String = "Seattle",
        stateCode: String = "WA",
        page: Int = 0,
        size: Int = 50,
        sort: String = "date,asc",
        classificationName: String? = nil,
        keyword: String? = nil,
        startDateTime: String? = nil,
        endDateTime: String? = nil
    ) async throws -> TMResponse {
        var components = URLComponents(string: "\(baseURL)/events.json")!
        var queryItems = [
            URLQueryItem(name: "apikey", value: apiKey),
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "stateCode", value: stateCode),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "sort", value: sort),
        ]

        if let classificationName {
            queryItems.append(URLQueryItem(name: "classificationName", value: classificationName))
        }
        if let keyword, !keyword.isEmpty {
            queryItems.append(URLQueryItem(name: "keyword", value: keyword))
        }
        if let startDateTime {
            queryItems.append(URLQueryItem(name: "startDateTime", value: startDateTime))
        }
        if let endDateTime {
            queryItems.append(URLQueryItem(name: "endDateTime", value: endDateTime))
        }

        components.queryItems = queryItems

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

            // Store image URL as part of a custom field approach
            if let imageURL = tmEvent.primaryImage?.url {
                event.imageURL = imageURL
            }

            context.insert(event)
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
