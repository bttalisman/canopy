import Foundation
import MapKit
import CoreLocation

actor TransitService {
    static let shared = TransitService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let obaBaseURL = "https://api.pugetsound.onebusaway.org/api/where"

    // Cache
    private var routeCache: [String: CachedRoutes] = [:]
    private var arrivalCache: [String: CachedArrivals] = [:]

    private struct CachedRoutes {
        let routes: [TransitRoute]
        let fetchedAt: Date
    }

    private struct CachedArrivals {
        let arrivals: [RealTimeArrival]
        let fetchedAt: Date
    }

    private func routeCacheKey(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> String {
        let fLat = (from.latitude * 1000).rounded() / 1000
        let fLng = (from.longitude * 1000).rounded() / 1000
        let tLat = (to.latitude * 1000).rounded() / 1000
        let tLng = (to.longitude * 1000).rounded() / 1000
        return "\(fLat),\(fLng)->\(tLat),\(tLng)"
    }

    // MARK: - Transit Routes via MKDirections

    func fetchTransitRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [TransitRoute] {
        let key = routeCacheKey(from: origin, to: destination)
        if let cached = routeCache[key], Date().timeIntervalSince(cached.fetchedAt) < 600 {
            return cached.routes
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .transit

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            let routes = response.routes.map { mapRoute($0) }
            routeCache[key] = CachedRoutes(routes: routes, fetchedAt: Date())
            return routes
        } catch {
            print("[Transit] MKDirections error: \(error.localizedDescription)")
            return []
        }
    }

    private nonisolated func mapRoute(_ mkRoute: MKRoute) -> TransitRoute {
        let steps = mkRoute.steps
            .filter { !$0.instructions.isEmpty }
            .map { step -> TransitStep in
                let type = mapTransportType(step)
                let lineName = extractLineName(from: step.instructions, type: type)

                return TransitStep(
                    instruction: step.instructions,
                    transportType: type,
                    lineName: lineName,
                    departureStopName: nil,
                    arrivalStopName: nil,
                    distance: step.distance > 0 ? step.distance : nil,
                    duration: step.distance > 0 ? step.distance / 1.4 : 0 // ~walking speed estimate
                )
            }

        return TransitRoute(
            steps: steps,
            totalTravelTime: mkRoute.expectedTravelTime,
            expectedDepartureTime: Date(),
            expectedArrivalTime: Date().addingTimeInterval(mkRoute.expectedTravelTime)
        )
    }

    private nonisolated func mapTransportType(_ step: MKRoute.Step) -> TransitStepType {
        let instruction = step.instructions.lowercased()

        if step.transportType == .walking || instruction.contains("walk") {
            return .walk
        }
        if instruction.contains("light rail") || instruction.contains("link") || instruction.contains("train") || instruction.contains("sounder") {
            return .train
        }
        if instruction.contains("ferry") || instruction.contains("water taxi") {
            return .ferry
        }
        if instruction.contains("bus") || instruction.contains("route") || instruction.contains("line") {
            return .bus
        }
        if step.transportType == .transit {
            return .bus
        }
        return .walk
    }

    private nonisolated func extractLineName(from instruction: String, type: TransitStepType) -> String? {
        guard type != .walk else { return nil }

        // Try to extract route/line name from instruction text
        // Common patterns: "Take Route 8", "Board Link Light Rail", "Take the 40"
        let patterns = [
            "take (route \\d+)",
            "take the (\\d+)",
            "board (.+?) (?:toward|to|at)",
            "take (.+?) (?:toward|to|at)",
            "(route \\d+)",
            "(line \\d+)",
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: instruction, range: NSRange(instruction.startIndex..., in: instruction)),
               match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: instruction) {
                return String(instruction[range]).capitalized
            }
        }

        // If it's a transit step but we can't extract the name, use the first few words
        if type != .walk {
            let words = instruction.split(separator: " ").prefix(4).joined(separator: " ")
            return words
        }

        return nil
    }

    // MARK: - OneBusAway: Nearby Stops

    func fetchNearbyStops(latitude: Double, longitude: Double, radius: Int = 400) async throws -> [OBAStop] {
        let apiKey = Secrets.oneBusAwayAPIKey
        guard !apiKey.isEmpty, apiKey != "YOUR_OBA_KEY_HERE" else { return [] }

        var components = URLComponents(string: "\(obaBaseURL)/stops-for-location.json")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
        ]

        guard let url = components.url else { throw TransitError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TransitError.serverError
        }

        let obaResponse = try decoder.decode(OBAResponse<OBAStopListData>.self, from: data)
        return obaResponse.data.list
    }

    // MARK: - OneBusAway: Arrivals at a Stop

    func fetchArrivals(stopId: String) async throws -> [RealTimeArrival] {
        if let cached = arrivalCache[stopId], Date().timeIntervalSince(cached.fetchedAt) < 60 {
            return cached.arrivals
        }

        let apiKey = Secrets.oneBusAwayAPIKey
        guard !apiKey.isEmpty, apiKey != "YOUR_OBA_KEY_HERE" else { return [] }

        var components = URLComponents(string: "\(obaBaseURL)/arrivals-and-departures-for-stop/\(stopId).json")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "minutesBefore", value: "0"),
            URLQueryItem(name: "minutesAfter", value: "60"),
        ]

        guard let url = components.url else { throw TransitError.invalidURL }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TransitError.serverError
        }

        let obaResponse = try decoder.decode(OBAResponse<OBAArrivalEntryData>.self, from: data)
        let now = Date().timeIntervalSince1970 * 1000

        // Look up stop name
        let stopName = stopId

        let arrivals = obaResponse.data.entry.arrivalsAndDepartures.compactMap { arrival -> RealTimeArrival? in
            let arrivalTime = arrival.predicted ? arrival.predictedArrivalTime : arrival.scheduledArrivalTime
            let minutesAway = Int((Double(arrivalTime) - now) / 60000)
            guard minutesAway >= 0 else { return nil }

            return RealTimeArrival(
                routeName: arrival.routeShortName ?? "?",
                headsign: arrival.tripHeadsign ?? "Unknown",
                minutesUntilArrival: minutesAway,
                isRealTime: arrival.predicted,
                stopName: stopName
            )
        }.sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }

        arrivalCache[stopId] = CachedArrivals(arrivals: arrivals, fetchedAt: Date())
        return arrivals
    }

    // MARK: - Convenience: Real-time arrivals near user

    func fetchRealTimeArrivals(latitude: Double, longitude: Double) async -> [RealTimeArrival] {
        do {
            let stops = try await fetchNearbyStops(latitude: latitude, longitude: longitude)
            let userLoc = CLLocation(latitude: latitude, longitude: longitude)

            // Sort by distance and take closest 3
            let closest = stops
                .sorted { CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: userLoc) < CLLocation(latitude: $1.lat, longitude: $1.lon).distance(from: userLoc) }
                .prefix(3)

            var allArrivals: [RealTimeArrival] = []
            for stop in closest {
                if let arrivals = try? await fetchArrivals(stopId: stop.id) {
                    let withStopName = arrivals.map { arrival in
                        RealTimeArrival(
                            routeName: arrival.routeName,
                            headsign: arrival.headsign,
                            minutesUntilArrival: arrival.minutesUntilArrival,
                            isRealTime: arrival.isRealTime,
                            stopName: stop.name
                        )
                    }
                    allArrivals.append(contentsOf: withStopName)
                }
            }

            // Deduplicate by route+headsign (keep soonest), return top 8
            var seen: Set<String> = []
            return allArrivals
                .sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }
                .filter { seen.insert("\($0.routeName)-\($0.headsign)").inserted }
                .prefix(8)
                .map { $0 }
        } catch {
            print("[Transit] OBA error: \(error.localizedDescription)")
            return []
        }
    }
}

enum TransitError: LocalizedError {
    case invalidURL
    case serverError
    case locationUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid transit API URL."
        case .serverError: return "Transit service unavailable."
        case .locationUnavailable: return "Location not available."
        }
    }
}
