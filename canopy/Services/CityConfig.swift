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
                NeighborhoodGroup(label: "Seattle", members: [
                    "Ballard", "Beacon Hill", "Bitter Lake", "Broadview", "Bryant",
                    "Capitol Hill", "Cascade", "Central Area", "Crown Hill", "Delridge",
                    "Downtown", "Fremont", "Georgetown", "Green Lake", "Greenwood",
                    "Harbor Island", "Industrial District", "Interbay", "Lake City",
                    "Laurelhurst", "Magnolia", "North Beach - Blue Ridge", "Northgate",
                    "Phinney Ridge", "Queen Anne", "Rainier Valley", "Ravenna",
                    "Roosevelt", "Sand Point", "Seward Park", "South Park",
                    "University District", "View Ridge", "Wallingford", "Wedgwood",
                    "West Seattle", "Windermere", "Shoreline",
                ]),
                NeighborhoodGroup(label: "Eastside", members: [
                    "Bellevue", "Bothell", "Issaquah", "Kenmore", "Kirkland",
                    "Mercer Island", "Newcastle", "Redmond", "Sammamish", "Woodinville",
                ]),
                NeighborhoodGroup(label: "Southside", members: [
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
