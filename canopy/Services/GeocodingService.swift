import Foundation
import CoreLocation

struct VenueBounds {
    let northeast: CLLocationCoordinate2D
    let southwest: CLLocationCoordinate2D

    var coordinates: [CLLocationCoordinate2D] {
        [
            CLLocationCoordinate2D(latitude: southwest.latitude, longitude: southwest.longitude),
            CLLocationCoordinate2D(latitude: southwest.latitude, longitude: northeast.longitude),
            CLLocationCoordinate2D(latitude: northeast.latitude, longitude: northeast.longitude),
            CLLocationCoordinate2D(latitude: northeast.latitude, longitude: southwest.longitude),
        ]
    }
}

enum GeocodingService {
    static func fetchBounds(for address: String) async -> VenueBounds? {
        guard let apiKey = Bundle.main.infoDictionary?["GOOGLE_MAPS_API_KEY"] as? String,
              !apiKey.isEmpty else { return nil }

        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        let urlString = "https://maps.googleapis.com/maps/api/geocode/json?address=\(encoded)&key=\(apiKey)"

        guard let url = URL(string: urlString) else { return nil }

        print("[Geocoding] Fetching bounds for: \(address)")
        print("[Geocoding] URL: \(urlString.replacingOccurrences(of: apiKey, with: "***"))")

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            let status = json?["status"] as? String ?? "unknown"
            print("[Geocoding] Status: \(status)")

            guard let results = json?["results"] as? [[String: Any]],
                  let first = results.first,
                  let geometry = first["geometry"] as? [String: Any],
                  let viewport = geometry["viewport"] as? [String: Any],
                  let ne = viewport["northeast"] as? [String: Double],
                  let sw = viewport["southwest"] as? [String: Double],
                  let neLat = ne["lat"], let neLng = ne["lng"],
                  let swLat = sw["lat"], let swLng = sw["lng"]
            else {
                print("[Geocoding] Failed to parse results")
                if let raw = String(data: data, encoding: .utf8) {
                    print("[Geocoding] Raw response: \(raw.prefix(500))")
                }
                return nil
            }

            let formattedAddress = first["formatted_address"] as? String ?? "?"
            print("[Geocoding] Resolved to: \(formattedAddress)")
            print("[Geocoding] Viewport NE: \(neLat), \(neLng) | SW: \(swLat), \(swLng)")

            return VenueBounds(
                northeast: CLLocationCoordinate2D(latitude: neLat, longitude: neLng),
                southwest: CLLocationCoordinate2D(latitude: swLat, longitude: swLng)
            )
        } catch {
            print("[Geocoding] Error: \(error)")
            return nil
        }
    }
}
