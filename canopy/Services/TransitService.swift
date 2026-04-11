import Foundation
import MapKit
import CoreLocation

actor TransitService {
    static let shared = TransitService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private let obaBaseURL = "https://api.pugetsound.onebusaway.org/api/where"
    private let otpBaseURL = "https://otp.prod.sound.obaweb.org/otp/routers/default"

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

    // MARK: - Transit Routes via OpenTripPlanner

    func fetchTransitRoutes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) async throws -> [TransitRoute] {
        let key = routeCacheKey(from: origin, to: destination)
        if let cached = routeCache[key], Date().timeIntervalSince(cached.fetchedAt) < 600 {
            return cached.routes
        }

        var components = URLComponents(string: "\(otpBaseURL)/plan")!
        components.queryItems = [
            URLQueryItem(name: "fromPlace", value: "\(origin.latitude),\(origin.longitude)"),
            URLQueryItem(name: "toPlace", value: "\(destination.latitude),\(destination.longitude)"),
            URLQueryItem(name: "mode", value: "TRANSIT,WALK"),
            URLQueryItem(name: "arriveBy", value: "false"),
            URLQueryItem(name: "maxWalkDistance", value: "800"),
            URLQueryItem(name: "numItineraries", value: "3"),
        ]

        guard let url = components.url else { throw TransitError.invalidURL }


        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            return []
        }

        let otpResponse = try decoder.decode(OTPResponse.self, from: data)
        guard let itineraries = otpResponse.plan?.itineraries else { return [] }

        let routes = itineraries.map { mapItinerary($0) }
        routeCache[key] = CachedRoutes(routes: routes, fetchedAt: Date())
        return routes
    }

    private nonisolated func mapItinerary(_ itinerary: OTPItinerary) -> TransitRoute {
        let steps = itinerary.legs.map { leg -> TransitStep in
            let type = mapOTPMode(leg.mode)
            let routeName = leg.routeShortName ?? leg.route

            let instruction: String
            if type == .walk {
                instruction = "Walk to \(leg.to.name)"
            } else {
                instruction = "Take \(routeName ?? leg.mode) to \(leg.to.name)"
            }

            return TransitStep(
                instruction: instruction,
                transportType: type,
                lineName: routeName,
                departureStopName: leg.from.name,
                arrivalStopName: leg.to.name,
                distance: leg.distance,
                duration: leg.duration
            )
        }

        return TransitRoute(
            steps: steps,
            totalTravelTime: Double(itinerary.duration),
            expectedDepartureTime: Date(timeIntervalSince1970: Double(itinerary.startTime) / 1000),
            expectedArrivalTime: Date(timeIntervalSince1970: Double(itinerary.endTime) / 1000)
        )
    }

    private nonisolated func mapOTPMode(_ mode: String) -> TransitStepType {
        switch mode.uppercased() {
        case "WALK": return .walk
        case "BUS": return .bus
        case "RAIL", "TRAM", "SUBWAY": return .train
        case "FERRY": return .ferry
        default: return .other
        }
    }

    // MARK: - OneBusAway: Nearby Stops

    func fetchNearbyStops(latitude: Double, longitude: Double, radius: Int = 400) async throws -> [OBAStop] {
        let apiKey = Secrets.oneBusAwayAPIKey
        guard !apiKey.isEmpty, apiKey != "YOUR_OBA_KEY_HERE" else {
            return []
        }

        var components = URLComponents(string: "\(obaBaseURL)/stops-for-location.json")!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lon", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius)),
        ]

        guard let url = components.url else { throw TransitError.invalidURL }


        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw TransitError.serverError
        }


        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw TransitError.serverError
        }

        return try Self.decodeStops(from: data)
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

        let arrivals = try Self.decodeArrivals(from: data)
        let now = Date().timeIntervalSince1970 * 1000

        // Look up stop name
        let stopName = stopId

        let results = arrivals.compactMap { arrival -> RealTimeArrival? in
            let arrivalTime = arrival.predicted ? arrival.predictedArrivalTime : arrival.scheduledArrivalTime
            let minutesAway = Int((Double(arrivalTime) - now) / 60000)
            guard minutesAway >= 0 else { return nil }

            return RealTimeArrival(
                routeId: arrival.routeId ?? "",
                routeName: arrival.routeShortName ?? "?",
                headsign: arrival.tripHeadsign ?? "Unknown",
                minutesUntilArrival: minutesAway,
                isRealTime: arrival.predicted,
                stopName: stopName
            )
        }.sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }

        arrivalCache[stopId] = CachedArrivals(arrivals: results, fetchedAt: Date())
        return results
    }

    // MARK: - Filtered arrivals: only routes that go to the venue

    func fetchTransitArrivals(
        userLatitude: Double, userLongitude: Double,
        venueLatitude: Double, venueLongitude: Double
    ) async -> [RealTimeArrival] {
        do {
            // 1. Find stops near the venue and collect route IDs that serve it
            let venueStops = try await fetchNearbyStops(latitude: venueLatitude, longitude: venueLongitude, radius: 500)
            let venueRouteIds = Set(venueStops.flatMap { $0.routeIds ?? [] })

            guard !venueRouteIds.isEmpty else { return [] }

            // 2. Find stops near the user
            let userStops = try await fetchNearbyStops(latitude: userLatitude, longitude: userLongitude, radius: 500)
            let userLoc = CLLocation(latitude: userLatitude, longitude: userLongitude)

            // 3. Filter to stops that share at least one route with the venue
            let relevantStops = userStops
                .filter { stop in
                    guard let stopRoutes = stop.routeIds else { return false }
                    return !Set(stopRoutes).isDisjoint(with: venueRouteIds)
                }
                .sorted { CLLocation(latitude: $0.lat, longitude: $0.lon).distance(from: userLoc) < CLLocation(latitude: $1.lat, longitude: $1.lon).distance(from: userLoc) }


            guard !relevantStops.isEmpty else { return [] }

            // 4. Get arrivals at the relevant stops, filtered to venue-bound routes only
            var allArrivals: [RealTimeArrival] = []
            for stop in relevantStops.prefix(5) {
                do {
                    let arrivals = try await fetchArrivals(stopId: stop.id)
                    let filtered = arrivals.filter { venueRouteIds.contains($0.routeId) }
                    let withStopName = filtered.map { arrival in
                        RealTimeArrival(
                            routeId: arrival.routeId,
                            routeName: arrival.routeName,
                            headsign: arrival.headsign,
                            minutesUntilArrival: arrival.minutesUntilArrival,
                            isRealTime: arrival.isRealTime,
                            stopName: stop.name
                        )
                    }
                    allArrivals.append(contentsOf: withStopName)
                } catch {
                }
            }

            // 5. Deduplicate and return
            var seen: Set<String> = []
            return allArrivals
                .sorted { $0.minutesUntilArrival < $1.minutesUntilArrival }
                .filter { seen.insert("\($0.routeName)-\($0.headsign)").inserted }
                .prefix(8)
                .map { $0 }
        } catch {
            return []
        }
    }

    private nonisolated static func decodeStops(from data: Data) throws -> [OBAStop] {
        try JSONDecoder().decode(OBAStopsResponse.self, from: data).data.list
    }

    private nonisolated static func decodeArrivals(from data: Data) throws -> [OBAArrival] {
        try JSONDecoder().decode(OBAArrivalsResponse.self, from: data).data.entry.arrivalsAndDepartures
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
