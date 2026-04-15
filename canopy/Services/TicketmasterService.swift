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
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "city", value: CityConfig.cityDisplayName),
        ]

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
    func importEvents(_ tmEvents: [TMEvent], into context: ModelContext, venues: [APIVenueBoundary] = []) -> Int {
        var importedCount = 0
        var skippedDuplicate = 0
        var skippedCurated = 0
        var skippedNoDate = 0

        for tmEvent in tmEvents {
            let venueCity = tmEvent.venue?.city?.name ?? "?"
            let venueName = tmEvent.venue?.name ?? "?"

            guard let startDate = tmEvent.startDate else {
                skippedNoDate += 1
                print("[TM] Skipped (no date): \(tmEvent.name) at \(venueName), \(venueCity)")
                continue
            }

            // Check for duplicates by name + start date
            let name = tmEvent.name
            let descriptor = FetchDescriptor<Event>(predicate: #Predicate {
                $0.name == name
            })

            let existing = (try? context.fetch(descriptor)) ?? []
            let isDuplicate = existing.contains { event in
                Calendar.current.isDate(event.startDate, inSameDayAs: startDate)
            }

            if isDuplicate {
                skippedDuplicate += 1
                // Override coords from admin venue if available
                if let event = existing.first,
                   let matchedVenue = venues.first(where: {
                       let a = $0.venueName.lowercased()
                       let b = event.location.lowercased()
                       return a == b || b.hasPrefix(a) || a.hasPrefix(b)
                   }),
                   let vLat = matchedVenue.latitude, let vLng = matchedVenue.longitude {
                    event.latitude = vLat
                    event.longitude = vLng
                    if let hood = NeighborhoodLookup.lookup(latitude: vLat, longitude: vLng) {
                        event.neighborhood = hood
                    }
                }
                // Backfill neighborhood from geo lookup if still set to city name
                else if let event = existing.first,
                   (event.neighborhood == CityConfig.defaultLocation || event.neighborhood == CityConfig.greaterAreaName),
                   let lat = event.latitude, let lng = event.longitude,
                   let hood = NeighborhoodLookup.lookup(latitude: lat, longitude: lng) {
                    event.neighborhood = hood
                }
                continue
            }

            // Skip if a curated event already covers this venue + date range
            let venueNameCheck = tmEvent.venue?.name ?? ""
            if !venueNameCheck.isEmpty {
                let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
                let coveredByCurated = allEvents.contains { curated in
                    curated.location.localizedCaseInsensitiveContains(venueNameCheck) &&
                    curated.startDate <= startDate &&
                    curated.endDate >= startDate &&
                    !curated.scheduleItems.isEmpty
                }
                if coveredByCurated {
                    skippedCurated += 1
                    print("[TM] Skipped (curated): \(tmEvent.name) at \(venueName), \(venueCity)")
                    continue
                }
            }

            print("[TM] Importing: \(tmEvent.name) at \(venueName), \(venueCity)")

            let endDate = tmEvent.endDate ?? Calendar.current.date(byAdding: .hour, value: 3, to: startDate)!

            let category = mapCategory(tmEvent.segmentName)

            let event = Event(
                name: tmEvent.name,
                slug: tmEvent.id,
                eventDescription: tmEvent.displayDescription,
                startDate: startDate,
                endDate: endDate,
                location: tmEvent.venue?.name ?? CityConfig.defaultLocation,
                neighborhood: CityConfig.greaterAreaName,
                logoSystemImage: category.systemImage,
                ticketingURL: tmEvent.url,
                category: category
            )

            if tmEvent.primaryImage?.url != nil, event.eventDescription.isEmpty {
                event.eventDescription = "Event at \(event.location)"
            }

            if let imageURL = tmEvent.primaryImage?.url {
                event.imageURL = imageURL
            }

            // Store venue coordinates and resolve neighborhood
            if let loc = tmEvent.venue?.location {
                event.latitude = loc.latitudeDouble
                event.longitude = loc.longitudeDouble
                if let lat = loc.latitudeDouble, let lng = loc.longitudeDouble,
                   let hood = NeighborhoodLookup.lookup(latitude: lat, longitude: lng) {
                    event.neighborhood = hood
                }
            }

            // Override coordinates from admin-defined venue (exact or prefix match)
            if let matchedVenue = venues.first(where: {
                let a = $0.venueName.lowercased()
                let b = event.location.lowercased()
                return a == b || b.hasPrefix(a) || a.hasPrefix(b)
            }) {
                if let lat = matchedVenue.latitude, let lng = matchedVenue.longitude {
                    print("[TM] Overriding coords for \(event.location) from admin venue: \(lat), \(lng)")
                    event.latitude = lat
                    event.longitude = lng
                    if let hood = NeighborhoodLookup.lookup(latitude: lat, longitude: lng) {
                        event.neighborhood = hood
                    }
                }
            }

            event.city = CityConfig.citySlug

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

        print("[TM] Summary: \(importedCount) imported, \(skippedDuplicate) duplicate, \(skippedCurated) curated, \(skippedNoDate) no date, \(tmEvents.count) total")
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
