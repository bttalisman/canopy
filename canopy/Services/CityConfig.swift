import SwiftUI

enum CityConfig {
    nonisolated(unsafe) static let citySlug: String = {
        Bundle.main.infoDictionary?["CANOPY_CITY"] as? String ?? "seattle"
    }()

    nonisolated(unsafe) static let cityDisplayName: String = {
        Bundle.main.infoDictionary?["CANOPY_CITY_DISPLAY_NAME"] as? String ?? "Seattle"
    }()

    static var appTitle: String { "Canopy \(cityDisplayName)" }

    static var eventsLoadingMessage: String { "Fetching \(cityDisplayName) events..." }

    static var onboardingSubtitle: String { "One app for every\n\(cityDisplayName) event" }

    static var settingsCityLabel: String {
        let labels: [String: String] = [
            "seattle": "Seattle, WA",
            "tacoma": "Tacoma, WA",
        ]
        return labels[citySlug] ?? cityDisplayName
    }

    static var accentGradientColors: [Color] {
        switch citySlug {
        case "seattle": return [.leafDark, .leafLight]
        case "tacoma": return [.blue, .cyan]
        default: return [.leafDark, .leafLight]
        }
    }

    static var defaultLocation: String { cityDisplayName }

    static var greaterAreaName: String { "Greater \(cityDisplayName)" }

    struct NeighborhoodGroup {
        let label: String
        let members: Set<String>
    }

    static var neighborhoodGroups: [NeighborhoodGroup] {
        switch citySlug {
        case "seattle":
            return [
                NeighborhoodGroup(label: "North Seattle", members: [
                    "Ballard", "Bitter Lake", "Broadview", "Bryant", "Crown Hill",
                    "Fremont", "Green Lake", "Greenwood", "Lake City",
                    "Laurelhurst", "North Beach - Blue Ridge", "Northgate",
                    "Phinney Ridge", "Ravenna", "Roosevelt", "Sand Point",
                    "Shoreline", "University District", "View Ridge",
                    "Wallingford", "Wedgwood", "Windermere",
                ]),
                NeighborhoodGroup(label: "Central Seattle", members: [
                    "Capitol Hill", "Cascade", "Central Area", "Central District",
                    "Chinatown-International District", "Downtown", "Downtown / Citywide",
                    "Interbay", "Lower Queen Anne", "Magnolia", "Pioneer Square",
                    "Queen Anne",
                ]),
                NeighborhoodGroup(label: "South Seattle", members: [
                    "Beacon Hill", "Delridge", "Georgetown", "Harbor Island",
                    "Industrial District", "Mount Baker", "Rainier Valley",
                    "Seward Park", "South Park", "West Seattle",
                ]),
                NeighborhoodGroup(label: "Eastside", members: [
                    "Bellevue", "Bothell", "Issaquah", "Kenmore", "Kirkland",
                    "Mercer Island", "Newcastle", "Redmond", "Sammamish", "Woodinville",
                ]),
                NeighborhoodGroup(label: "South King", members: [
                    "Auburn", "Burien", "Des Moines", "Federal Way", "Kent",
                    "Renton", "SeaTac", "Tukwila",
                ]),
            ]
        default:
            return []
        }
    }

    static func groupLabel(for neighborhood: String) -> String? {
        for group in neighborhoodGroups {
            if group.members.contains(neighborhood) {
                return group.label
            }
        }
        return nil
    }
}
