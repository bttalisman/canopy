import Foundation
import CoreLocation

struct StreetClosure: Identifiable, Decodable {
    let id: String
    let description: String
    let coordinates: [[Double]]   // [[lat, lng], ...]
    let startDate: String?
    let endDate: String?
    let source: String?

    var clCoordinates: [CLLocationCoordinate2D] {
        coordinates.compactMap { pair in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }
}

actor StreetClosureService {
    static let shared = StreetClosureService()

    private let session = URLSession.shared
    private var cache: [String: [StreetClosure]] = [:]

    func fetch(near coordinate: CLLocationCoordinate2D, startDate: Date, endDate: Date) async throws -> [StreetClosure] {
        let baseURL = Secrets.canopyAPIBaseURL
        guard !baseURL.isEmpty, baseURL != "YOUR_API_URL_HERE" else { return [] }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let startStr = formatter.string(from: startDate)
        let endStr = formatter.string(from: endDate)

        let cacheKey = "\(coordinate.latitude),\(coordinate.longitude)|\(startStr)|\(endStr)"
        if let cached = cache[cacheKey] { return cached }

        var components = URLComponents(string: "\(baseURL)/api/street-closures")!
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(coordinate.longitude)),
            URLQueryItem(name: "startDate", value: startStr),
            URLQueryItem(name: "endDate", value: endStr),
        ]

        guard let url = components.url else { return [] }
        let (data, _) = try await session.data(from: url)
        let result = try JSONDecoder().decode([StreetClosure].self, from: data)
        cache[cacheKey] = result
        return result
    }
}
