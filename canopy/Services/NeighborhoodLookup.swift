import Foundation

/// Resolves a lat/lng coordinate to a neighborhood name using bundled GeoJSON boundary data.
enum NeighborhoodLookup {
    private struct Hood {
        let name: String
        let polygon: [(Double, Double)] // (lng, lat) pairs
    }

    private static let hoods: [Hood] = {
        let filename = "\(CityConfig.citySlug)-neighborhoods"
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else {
            print("[NeighborhoodLookup] Could not load \(filename).json")
            return []
        }

        return entries.compactMap { entry in
            guard let name = entry["n"] as? String,
                  let coords = entry["c"] as? [[Double]]
            else { return nil }
            let polygon = coords.map { ($0[0], $0[1]) }
            return Hood(name: name, polygon: polygon)
        }
    }()

    /// Returns the neighborhood name for the given coordinates, or nil if not found.
    static func lookup(latitude: Double, longitude: Double) -> String? {
        for hood in hoods {
            if pointInPolygon(x: longitude, y: latitude, polygon: hood.polygon) {
                return hood.name
            }
        }
        return nil
    }

    /// Ray-casting point-in-polygon test.
    private static func pointInPolygon(x: Double, y: Double, polygon: [(Double, Double)]) -> Bool {
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].0, yi = polygon[i].1
            let xj = polygon[j].0, yj = polygon[j].1
            if ((yi > y) != (yj > y)) &&
                (x < (xj - xi) * (y - yi) / (yj - yi) + xi) {
                inside.toggle()
            }
            j = i
        }
        return inside
    }
}
