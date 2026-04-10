import SwiftUI

enum CityConfig {
    static let citySlug: String = {
        Bundle.main.infoDictionary?["CANOPY_CITY"] as? String ?? "seattle"
    }()

    static let cityDisplayName: String = {
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
}
