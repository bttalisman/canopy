import Foundation
import SwiftData

struct VenueTemplate {
    let matchPatterns: [String] // venue names to match against (lowercased)
    let neighborhood: String
    let latitude: Double
    let longitude: Double
    let mapSpan: Double // degrees to show around the center point
    let pins: [PinTemplate]
    let stages: [StageTemplate]
    var boundaryCoords: [(Double, Double)] = [] // manual polygon (lat, lng) pairs
}

struct PinTemplate {
    let label: String
    let pinType: MapPinType
    let x: Double
    let y: Double
    let pinDescription: String

    init(_ label: String, _ pinType: MapPinType, x: Double, y: Double, description: String = "") {
        self.label = label
        self.pinType = pinType
        self.x = x
        self.y = y
        self.pinDescription = description
    }
}

struct StageTemplate {
    let name: String
    let x: Double
    let y: Double
}

enum VenueMapData {

    static let venues: [VenueTemplate] = [

        // MARK: - Seattle Center
        VenueTemplate(
            matchPatterns: ["seattle center", "bumbershoot", "northwest folklife", "folklife", "bite of seattle"],
            neighborhood: "Lower Queen Anne",
            latitude: 47.6215, longitude: -122.3510, mapSpan: 0.005,
            pins: [
                PinTemplate("KeyArena Plaza", .stage, x: 0.45, y: 0.25, description: "Main outdoor performance area"),
                PinTemplate("Fisher Pavilion", .stage, x: 0.28, y: 0.48, description: "Covered performance venue"),
                PinTemplate("Mural Amphitheatre", .stage, x: 0.72, y: 0.38, description: "Outdoor amphitheatre by the Mural"),
                PinTemplate("Fountain Lawn", .stage, x: 0.50, y: 0.40, description: "Open lawn around the International Fountain"),
                PinTemplate("Armory (Food Court)", .food, x: 0.48, y: 0.55, description: "Indoor food hall with 20+ vendors"),
                PinTemplate("Food Trucks North", .food, x: 0.35, y: 0.20, description: "Rotating food truck lineup"),
                PinTemplate("Food Trucks South", .food, x: 0.60, y: 0.70, description: "Additional food vendors"),
                PinTemplate("Restrooms - North", .restroom, x: 0.20, y: 0.22),
                PinTemplate("Restrooms - Armory", .restroom, x: 0.52, y: 0.58),
                PinTemplate("Restrooms - South", .restroom, x: 0.78, y: 0.72),
                PinTemplate("First Aid Station", .firstAid, x: 0.15, y: 0.45, description: "Medical services & lost children"),
                PinTemplate("Main Entry (Mercer St)", .exit, x: 0.50, y: 0.92, description: "Primary entrance from Mercer Street"),
                PinTemplate("North Entry (Republican St)", .exit, x: 0.50, y: 0.08, description: "Entrance near Space Needle"),
                PinTemplate("West Entry (1st Ave)", .exit, x: 0.08, y: 0.50, description: "Entrance from 1st Avenue"),
                PinTemplate("Space Needle", .custom, x: 0.38, y: 0.12, description: "Landmark — not part of event grounds"),
                PinTemplate("KEXP Stage", .stage, x: 0.18, y: 0.35, description: "KEXP live broadcast stage"),
            ],
            stages: [
                StageTemplate(name: "KeyArena Plaza Stage", x: 0.45, y: 0.25),
                StageTemplate(name: "Fisher Pavilion", x: 0.28, y: 0.48),
                StageTemplate(name: "Mural Amphitheatre", x: 0.72, y: 0.38),
                StageTemplate(name: "Fountain Lawn Stage", x: 0.50, y: 0.40),
                StageTemplate(name: "KEXP Stage", x: 0.18, y: 0.35),
            ]
        ),

        // MARK: - Climate Pledge Arena
        VenueTemplate(
            matchPatterns: ["climate pledge arena"],
            neighborhood: "Lower Queen Anne",
            latitude: 47.6221, longitude: -122.3540, mapSpan: 0.003,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.40, description: "Center arena floor/stage"),
                PinTemplate("Main Concourse Food", .food, x: 0.50, y: 0.15, description: "Concessions on main level"),
                PinTemplate("Upper Concourse Food", .food, x: 0.50, y: 0.75, description: "Upper level concessions"),
                PinTemplate("The Ninety Bar", .food, x: 0.80, y: 0.30, description: "Premium bar & lounge"),
                PinTemplate("Restrooms - Section 100", .restroom, x: 0.20, y: 0.30),
                PinTemplate("Restrooms - Section 200", .restroom, x: 0.80, y: 0.60),
                PinTemplate("Restrooms - Upper Level", .restroom, x: 0.20, y: 0.70),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.50, description: "Section 126"),
                PinTemplate("Main Entrance (1st Ave N)", .exit, x: 0.50, y: 0.95),
                PinTemplate("VIP Entrance", .exit, x: 0.85, y: 0.50, description: "Premium/suite entrance"),
                PinTemplate("Merch Stand", .custom, x: 0.35, y: 0.15, description: "Official merchandise"),
                PinTemplate("Box Office", .custom, x: 0.45, y: 0.90, description: "Will call & ticket sales"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.40),
            ]
        ),

        // MARK: - Washington State Convention Center
        VenueTemplate(
            matchPatterns: ["washington state convention center", "wscc", "convention center", "pax west", "emerald city comic con", "eccc"],
            neighborhood: "Downtown",
            latitude: 47.6117, longitude: -122.3316, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Hall", .stage, x: 0.50, y: 0.30, description: "Primary exhibition/event space"),
                PinTemplate("Exhibit Hall 4A-B", .stage, x: 0.35, y: 0.45, description: "Large expo floor"),
                PinTemplate("Ballroom 6A-C", .stage, x: 0.65, y: 0.25, description: "Panels & presentations"),
                PinTemplate("Summit Building", .stage, x: 0.75, y: 0.55, description: "Expanded convention space (new building)"),
                PinTemplate("Food Court - Level 3", .food, x: 0.40, y: 0.55, description: "Main food court"),
                PinTemplate("Food Court - Level 6", .food, x: 0.60, y: 0.40, description: "Upper level dining"),
                PinTemplate("Starbucks Lobby", .food, x: 0.30, y: 0.85, description: "Coffee & pastries"),
                PinTemplate("Restrooms - Level 1", .restroom, x: 0.20, y: 0.80),
                PinTemplate("Restrooms - Level 3", .restroom, x: 0.20, y: 0.45),
                PinTemplate("Restrooms - Level 6", .restroom, x: 0.80, y: 0.30),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.60, description: "Level 3, near registration"),
                PinTemplate("Main Entrance (Pike St)", .exit, x: 0.50, y: 0.95, description: "Pike Street entrance"),
                PinTemplate("Skybridge to Summit", .exit, x: 0.70, y: 0.50, description: "Covered walkway to Summit building"),
                PinTemplate("Registration", .custom, x: 0.45, y: 0.85, description: "Badge pickup & check-in"),
            ],
            stages: [
                StageTemplate(name: "Main Hall", x: 0.50, y: 0.30),
                StageTemplate(name: "Exhibit Hall 4", x: 0.35, y: 0.45),
                StageTemplate(name: "Ballroom 6", x: 0.65, y: 0.25),
                StageTemplate(name: "Summit Building", x: 0.75, y: 0.55),
            ]
        ),

        // MARK: - T-Mobile Park
        VenueTemplate(
            matchPatterns: ["t-mobile park"],
            neighborhood: "SoDo",
            latitude: 47.5914, longitude: -122.3325, mapSpan: 0.004,
            pins: [
                PinTemplate("Home Plate Field", .stage, x: 0.50, y: 0.45, description: "Main field / performance area"),
                PinTemplate("The 'Pen (Bullpen Bar)", .food, x: 0.75, y: 0.65, description: "Craft beer & food in the bullpen"),
                PinTemplate("Edgar's Cantina", .food, x: 0.30, y: 0.25, description: "Mexican food & margaritas"),
                PinTemplate("Main Concourse Food", .food, x: 0.50, y: 0.20, description: "Hot dogs, garlic fries, clam chowder"),
                PinTemplate("Ivar's", .food, x: 0.65, y: 0.20, description: "Seattle seafood"),
                PinTemplate("Restrooms - Section 110", .restroom, x: 0.25, y: 0.40),
                PinTemplate("Restrooms - Section 130", .restroom, x: 0.75, y: 0.40),
                PinTemplate("Restrooms - Upper Deck", .restroom, x: 0.50, y: 0.15),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.55, description: "Behind Section 128"),
                PinTemplate("Home Plate Gate", .exit, x: 0.50, y: 0.92, description: "Main entrance — 1st Ave S"),
                PinTemplate("Left Field Gate", .exit, x: 0.12, y: 0.50, description: "Edgar Martinez Dr entrance"),
                PinTemplate("Right Field Gate", .exit, x: 0.88, y: 0.50),
                PinTemplate("Team Store", .custom, x: 0.40, y: 0.88, description: "Official Mariners merchandise"),
            ],
            stages: [
                StageTemplate(name: "Main Field", x: 0.50, y: 0.45),
            ]
        ),

        // MARK: - Lumen Field
        VenueTemplate(
            matchPatterns: ["lumen field"],
            neighborhood: "SoDo",
            latitude: 47.5952, longitude: -122.3316, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Field", .stage, x: 0.50, y: 0.45, description: "Field level stage / performance area"),
                PinTemplate("North End Food Court", .food, x: 0.45, y: 0.15, description: "Concessions — north side"),
                PinTemplate("South End Food Court", .food, x: 0.55, y: 0.80, description: "Concessions — south side"),
                PinTemplate("Craft Beer Garden", .food, x: 0.80, y: 0.35, description: "Local microbrews"),
                PinTemplate("Restrooms - North", .restroom, x: 0.25, y: 0.20),
                PinTemplate("Restrooms - South", .restroom, x: 0.75, y: 0.75),
                PinTemplate("Restrooms - East", .restroom, x: 0.85, y: 0.50),
                PinTemplate("First Aid", .firstAid, x: 0.12, y: 0.45, description: "West concourse"),
                PinTemplate("North Gate", .exit, x: 0.50, y: 0.05, description: "Main north entrance"),
                PinTemplate("South Gate", .exit, x: 0.50, y: 0.95),
                PinTemplate("Pro Shop", .custom, x: 0.35, y: 0.90, description: "Official team merchandise"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.45),
            ]
        ),

        // MARK: - Paramount Theatre
        VenueTemplate(
            matchPatterns: ["paramount theatre", "paramount theater"],
            neighborhood: "Downtown",
            latitude: 47.6133, longitude: -122.3314, mapSpan: 0.002,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Historic proscenium stage"),
                PinTemplate("Lobby Bar", .food, x: 0.50, y: 0.80, description: "Drinks & snacks"),
                PinTemplate("Mezzanine Bar", .food, x: 0.50, y: 0.55, description: "Upper level concessions"),
                PinTemplate("Restrooms - Orchestra", .restroom, x: 0.20, y: 0.70),
                PinTemplate("Restrooms - Mezzanine", .restroom, x: 0.80, y: 0.50),
                PinTemplate("Main Entrance (Pine St)", .exit, x: 0.50, y: 0.95),
                PinTemplate("Box Office", .custom, x: 0.35, y: 0.92, description: "Will call & tickets"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
            ]
        ),

        // MARK: - The Showbox
        VenueTemplate(
            matchPatterns: ["showbox sodo", "showbox at the market", "the showbox", "showbox"],
            neighborhood: "Downtown",
            latitude: 47.6087, longitude: -122.3404, mapSpan: 0.002,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.25, description: "Performance stage"),
                PinTemplate("Main Bar", .food, x: 0.80, y: 0.50, description: "Full bar"),
                PinTemplate("Back Bar", .food, x: 0.20, y: 0.60),
                PinTemplate("Restrooms", .restroom, x: 0.15, y: 0.75),
                PinTemplate("Merch Table", .custom, x: 0.85, y: 0.80, description: "Artist merchandise"),
                PinTemplate("Main Entrance", .exit, x: 0.50, y: 0.95),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.25),
            ]
        ),

        // MARK: - Gas Works Park
        VenueTemplate(
            matchPatterns: ["gas works park", "gasworks"],
            neighborhood: "Wallingford",
            latitude: 47.6456, longitude: -122.3344, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Lawn Stage", .stage, x: 0.50, y: 0.40, description: "Open field stage area"),
                PinTemplate("Hilltop", .custom, x: 0.55, y: 0.20, description: "Best view of the skyline"),
                PinTemplate("Food Vendors", .food, x: 0.35, y: 0.60, description: "Food trucks & vendors"),
                PinTemplate("Restrooms", .restroom, x: 0.25, y: 0.50),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.40),
                PinTemplate("North Entry (N Northlake Way)", .exit, x: 0.50, y: 0.05),
                PinTemplate("South Entry (Meridian Ave)", .exit, x: 0.50, y: 0.90),
            ],
            stages: [
                StageTemplate(name: "Main Lawn Stage", x: 0.50, y: 0.40),
            ]
        ),

        // MARK: - Volunteer Park / Cal Anderson Park (Capitol Hill)
        VenueTemplate(
            matchPatterns: ["volunteer park", "cal anderson", "capitol hill", "seattle pride"],
            neighborhood: "Capitol Hill",
            latitude: 47.6164, longitude: -122.3196, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Primary performance stage"),
                PinTemplate("Community Stage", .stage, x: 0.30, y: 0.55, description: "Local performers & speakers"),
                PinTemplate("Dance Area", .stage, x: 0.70, y: 0.50, description: "DJ & dance floor"),
                PinTemplate("Food Vendors", .food, x: 0.55, y: 0.65, description: "Local restaurant vendors"),
                PinTemplate("Beer Garden", .food, x: 0.75, y: 0.35, description: "21+ with ID"),
                PinTemplate("Restrooms - North", .restroom, x: 0.20, y: 0.25),
                PinTemplate("Restrooms - South", .restroom, x: 0.80, y: 0.70),
                PinTemplate("First Aid & Info", .firstAid, x: 0.15, y: 0.50, description: "Medical, info booth, lost & found"),
                PinTemplate("Main Entry", .exit, x: 0.50, y: 0.92),
                PinTemplate("North Entry", .exit, x: 0.50, y: 0.08),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
                StageTemplate(name: "Community Stage", x: 0.30, y: 0.55),
                StageTemplate(name: "Dance Area", x: 0.70, y: 0.50),
            ]
        ),

        // MARK: - The Gorge Amphitheatre (bonus — close enough to Seattle)
        VenueTemplate(
            matchPatterns: ["the gorge", "gorge amphitheatre", "gorge amphitheater"],
            neighborhood: "George, WA",
            latitude: 47.1028, longitude: -119.9962, mapSpan: 0.006,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Amphitheatre main stage with Columbia River gorge backdrop"),
                PinTemplate("Secondary Stage", .stage, x: 0.25, y: 0.55, description: "Smaller side stage"),
                PinTemplate("General Admission Lawn", .custom, x: 0.50, y: 0.55, description: "Open hillside seating"),
                PinTemplate("Food Village", .food, x: 0.70, y: 0.65, description: "Multiple food vendors"),
                PinTemplate("Beer Garden", .food, x: 0.30, y: 0.70, description: "21+ with ID"),
                PinTemplate("Restrooms - Upper", .restroom, x: 0.20, y: 0.75),
                PinTemplate("Restrooms - Lower", .restroom, x: 0.80, y: 0.45),
                PinTemplate("First Aid", .firstAid, x: 0.10, y: 0.50),
                PinTemplate("Main Gate", .exit, x: 0.50, y: 0.95),
                PinTemplate("Camping Check-In", .custom, x: 0.85, y: 0.85, description: "Overnight camping registration"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
                StageTemplate(name: "Secondary Stage", x: 0.25, y: 0.55),
            ]
        ),
        // MARK: - Genesee Park / Seafair
        VenueTemplate(
            matchPatterns: ["genesee park", "seafair", "lake washington"],
            neighborhood: "Mount Baker",
            latitude: 47.5535, longitude: -122.2612, mapSpan: 0.012,
            pins: [
                PinTemplate("Air Show Viewing Area", .custom, x: 0.50, y: 0.20, description: "Best views of the Blue Angels over Lake Washington"),
                PinTemplate("Hydroplane Pit", .stage, x: 0.60, y: 0.35, description: "H1 Unlimited race viewing"),
                PinTemplate("Festival Stage", .stage, x: 0.30, y: 0.45, description: "Live music and entertainment"),
                PinTemplate("Food Court", .food, x: 0.45, y: 0.55, description: "Festival food vendors"),
                PinTemplate("Beer Garden", .food, x: 0.65, y: 0.55, description: "21+ with ID"),
                PinTemplate("Restrooms - North", .restroom, x: 0.35, y: 0.30),
                PinTemplate("Restrooms - South", .restroom, x: 0.55, y: 0.70),
                PinTemplate("First Aid", .firstAid, x: 0.25, y: 0.60),
                PinTemplate("Main Entrance", .exit, x: 0.50, y: 0.90),
                PinTemplate("Boat Launch", .custom, x: 0.70, y: 0.15, description: "Lake access for watercraft viewing"),
            ],
            stages: [
                StageTemplate(name: "Hydroplane Pit", x: 0.60, y: 0.35),
                StageTemplate(name: "Air Show Viewing", x: 0.50, y: 0.20),
                StageTemplate(name: "Festival Stage", x: 0.30, y: 0.45),
            ]
        ),

        // MARK: - Pike/Pine Corridor (Capitol Hill Block Party)
        VenueTemplate(
            matchPatterns: ["pike/pine", "pike pine", "capitol hill block party", "chbp"],
            neighborhood: "Capitol Hill",
            latitude: 47.6145, longitude: -122.3210, mapSpan: 0.005,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.25, description: "Headliner stage on Pike St"),
                PinTemplate("Vera Stage", .stage, x: 0.20, y: 0.50, description: "Vera Project stage"),
                PinTemplate("Neumos Stage", .stage, x: 0.80, y: 0.45, description: "Indoor stage at Neumos"),
                PinTemplate("Food Vendors", .food, x: 0.40, y: 0.60, description: "Street food from Capitol Hill restaurants"),
                PinTemplate("Beer Garden", .food, x: 0.65, y: 0.65, description: "21+ with ID"),
                PinTemplate("Restrooms - Pike", .restroom, x: 0.30, y: 0.35),
                PinTemplate("Restrooms - Pine", .restroom, x: 0.70, y: 0.75),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.40),
                PinTemplate("Entrance - Broadway", .exit, x: 0.10, y: 0.50),
                PinTemplate("Entrance - 12th Ave", .exit, x: 0.90, y: 0.50),
                PinTemplate("Art Installations", .custom, x: 0.55, y: 0.80, description: "Interactive art along Pine St"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.25),
                StageTemplate(name: "Vera Stage", x: 0.20, y: 0.50),
                StageTemplate(name: "Neumos Stage", x: 0.80, y: 0.45),
            ]
        ),

        // MARK: - West Seattle Junction
        VenueTemplate(
            matchPatterns: ["west seattle junction", "west seattle summer", "junction"],
            neighborhood: "West Seattle",
            latitude: 47.5605, longitude: -122.3868, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Live music stage on California Ave"),
                PinTemplate("Kids Zone", .custom, x: 0.25, y: 0.55, description: "Activities, face painting, and games"),
                PinTemplate("Food Vendors", .food, x: 0.60, y: 0.50, description: "Local restaurant booths"),
                PinTemplate("Beer Garden", .food, x: 0.75, y: 0.40, description: "21+ with ID"),
                PinTemplate("Arts & Crafts", .custom, x: 0.40, y: 0.70, description: "Local artisan vendor booths"),
                PinTemplate("Restrooms", .restroom, x: 0.30, y: 0.80),
                PinTemplate("First Aid", .firstAid, x: 0.20, y: 0.35),
                PinTemplate("Entrance - Alaska", .exit, x: 0.50, y: 0.95),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
                StageTemplate(name: "Kids Zone", x: 0.25, y: 0.55),
            ]
        ),

        // MARK: - Hing Hay Park (CID Dragon Fest)
        VenueTemplate(
            matchPatterns: ["hing hay", "dragon fest", "chinatown", "international district"],
            neighborhood: "Chinatown-International District",
            latitude: 47.5984, longitude: -122.3232, mapSpan: 0.003,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.35, description: "Performances and ceremonies"),
                PinTemplate("Dragon Dance Route", .custom, x: 0.40, y: 0.20, description: "Dragon and lion dance parade path"),
                PinTemplate("Food Vendors", .food, x: 0.70, y: 0.55, description: "Asian street food from local restaurants"),
                PinTemplate("Night Market", .food, x: 0.30, y: 0.65, description: "Evening food and craft vendors"),
                PinTemplate("Restrooms", .restroom, x: 0.20, y: 0.45),
                PinTemplate("First Aid", .firstAid, x: 0.80, y: 0.40),
                PinTemplate("Entrance - King St", .exit, x: 0.50, y: 0.90),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.35),
            ]
        ),
        // MARK: - Fremont (Solstice Parade & Fair)
        VenueTemplate(
            matchPatterns: ["fremont", "solstice"],
            neighborhood: "Fremont",
            latitude: 47.6510, longitude: -122.3500, mapSpan: 0.005,
            pins: [
                PinTemplate("Parade Start", .custom, x: 0.20, y: 0.20, description: "Parade begins at N 36th St"),
                PinTemplate("Parade End / Fair", .stage, x: 0.60, y: 0.50, description: "Fair grounds and stage"),
                PinTemplate("Food Vendors", .food, x: 0.50, y: 0.60, description: "Street food and local restaurants"),
                PinTemplate("Beer Garden", .food, x: 0.70, y: 0.65, description: "21+ with ID"),
                PinTemplate("Restrooms", .restroom, x: 0.40, y: 0.75),
                PinTemplate("First Aid", .firstAid, x: 0.30, y: 0.55),
                PinTemplate("Fremont Troll", .custom, x: 0.15, y: 0.40, description: "The famous Fremont Troll under Aurora Bridge"),
            ],
            stages: [
                StageTemplate(name: "Parade Route", x: 0.40, y: 0.30),
                StageTemplate(name: "Fair Stage", x: 0.60, y: 0.50),
            ]
        ),

        // MARK: - Judkins Park (Juneteenth)
        VenueTemplate(
            matchPatterns: ["judkins", "juneteenth"],
            neighborhood: "Central District",
            latitude: 47.5945, longitude: -122.3028, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Performances and speakers"),
                PinTemplate("Food Vendors", .food, x: 0.65, y: 0.55, description: "BBQ and soul food vendors"),
                PinTemplate("Community Village", .custom, x: 0.35, y: 0.55, description: "Local organizations and vendors"),
                PinTemplate("Kids Area", .custom, x: 0.25, y: 0.70, description: "Activities for children"),
                PinTemplate("Restrooms", .restroom, x: 0.75, y: 0.65),
                PinTemplate("First Aid", .firstAid, x: 0.20, y: 0.40),
                PinTemplate("Entrance", .exit, x: 0.50, y: 0.90),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
            ]
        ),

        // MARK: - Ballard Avenue (SeafoodFest)
        VenueTemplate(
            matchPatterns: ["ballard avenue", "ballard seafood", "seafoodfest"],
            neighborhood: "Ballard",
            latitude: 47.6634, longitude: -122.3838, mapSpan: 0.004,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.25, description: "Live music on Ballard Ave"),
                PinTemplate("Beer Garden Stage", .stage, x: 0.75, y: 0.55, description: "Acoustic sets in the beer garden"),
                PinTemplate("Seafood Row", .food, x: 0.40, y: 0.45, description: "Salmon, crab, oysters, and more"),
                PinTemplate("Beer Garden", .food, x: 0.70, y: 0.50, description: "Craft beer from PNW breweries"),
                PinTemplate("Lutefisk Arena", .custom, x: 0.30, y: 0.60, description: "Home of the legendary eating contest"),
                PinTemplate("Restrooms - North", .restroom, x: 0.25, y: 0.30),
                PinTemplate("Restrooms - South", .restroom, x: 0.60, y: 0.75),
                PinTemplate("First Aid", .firstAid, x: 0.15, y: 0.50),
                PinTemplate("Entrance", .exit, x: 0.50, y: 0.90),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.25),
                StageTemplate(name: "Beer Garden Stage", x: 0.75, y: 0.55),
            ]
        ),

        // MARK: - Tractor Tavern
        VenueTemplate(
            matchPatterns: ["tractor tavern", "tractor"],
            neighborhood: "Ballard",
            latitude: 47.6636, longitude: -122.3846, mapSpan: 0.002,
            pins: [
                PinTemplate("Stage", .stage, x: 0.50, y: 0.25, description: "Main performance stage"),
                PinTemplate("Bar", .food, x: 0.70, y: 0.50, description: "Full bar"),
                PinTemplate("Sound Booth", .custom, x: 0.50, y: 0.60, description: "Sound and lighting"),
                PinTemplate("Restrooms", .restroom, x: 0.25, y: 0.70),
                PinTemplate("Front Entrance", .exit, x: 0.50, y: 0.90, description: "5213 Ballard Ave NW"),
            ],
            stages: [
                StageTemplate(name: "Stage", x: 0.50, y: 0.25),
            ]
        ),

        // MARK: - Chop Suey
        VenueTemplate(
            matchPatterns: ["chop suey"],
            neighborhood: "Capitol Hill",
            latitude: 47.6148, longitude: -122.3185, mapSpan: 0.002,
            pins: [
                PinTemplate("Main Stage", .stage, x: 0.50, y: 0.30, description: "Indoor main stage"),
                PinTemplate("Bar", .food, x: 0.75, y: 0.50, description: "Full bar with cocktails and beer"),
                PinTemplate("Restrooms", .restroom, x: 0.25, y: 0.65),
                PinTemplate("Front Entrance", .exit, x: 0.50, y: 0.90, description: "1325 E Madison St"),
                PinTemplate("Merch Table", .custom, x: 0.80, y: 0.70, description: "Artist merchandise"),
            ],
            stages: [
                StageTemplate(name: "Main Stage", x: 0.50, y: 0.30),
            ]
        ),
    ]

    // MARK: - Matching & Attaching

    /// Find the best venue template for a given event location string.
    static func findVenue(for locationName: String) -> VenueTemplate? {
        let lowered = locationName.lowercased()
        return venues.first { template in
            template.matchPatterns.contains { pattern in
                lowered.contains(pattern)
            }
        }
    }

    /// Attach map pins and stages from a venue template to an event.
    @MainActor
    static func attachMapData(to event: Event, using context: ModelContext) {
        // Don't re-add if the event already has map pins
        guard event.mapPins.isEmpty else { return }

        guard let venue = findVenue(for: event.location) else { return }

        // Update neighborhood if it's just "Seattle"
        if event.neighborhood == "Seattle" || event.neighborhood.isEmpty {
            event.neighborhood = venue.neighborhood
        }

        // Set venue coordinates if not already set
        if event.latitude == nil || event.longitude == nil {
            event.latitude = venue.latitude
            event.longitude = venue.longitude
        }

        // Add map pins
        for template in venue.pins {
            let pin = MapPin(
                label: template.label,
                pinType: template.pinType,
                x: template.x,
                y: template.y,
                pinDescription: template.pinDescription
            )
            pin.event = event
            context.insert(pin)
        }

        // Add stages
        for template in venue.stages {
            let stage = Stage(name: template.name, mapX: template.x, mapY: template.y)
            stage.event = event
            context.insert(stage)
        }
    }
}
