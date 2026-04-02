import Foundation
import SwiftData

struct SampleData {
    static func seed(into context: ModelContext) {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())

        // Helper to create dates
        func date(_ month: Int, _ day: Int, _ hour: Int = 10, _ minute: Int = 0) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)) ?? Date()
        }

        // MARK: - Bumbershoot

        let bumbershoot = Event(
            name: "Bumbershoot",
            slug: "bumbershoot",
            eventDescription: "Seattle's premier music and arts festival at Seattle Center. Three days of live music, comedy, film, visual arts, and more.",
            startDate: date(8, 30),
            endDate: date(9, 1),
            location: "Seattle Center",
            neighborhood: "Lower Queen Anne",
            logoSystemImage: "music.note.list",
            ticketingURL: "https://www.bumbershoot.com/tickets",
            category: .festival
        )

        let bMainStage = Stage(name: "Main Stage", mapX: 0.5, mapY: 0.25)
        let bFisherPavilion = Stage(name: "Fisher Pavilion", mapX: 0.3, mapY: 0.5)
        let bMural = Stage(name: "Mural Amphitheatre", mapX: 0.7, mapY: 0.4)
        bMainStage.event = bumbershoot
        bFisherPavilion.event = bumbershoot
        bMural.event = bumbershoot

        let bSchedule: [ScheduleItem] = [
            ScheduleItem(title: "The Head and the Heart", itemDescription: "Indie folk headliner from Seattle", startTime: date(8, 30, 20, 0), endTime: date(8, 30, 21, 30), category: "Music"),
            ScheduleItem(title: "Local Natives", itemDescription: "Indie rock from Los Angeles", startTime: date(8, 30, 17, 0), endTime: date(8, 30, 18, 30), category: "Music"),
            ScheduleItem(title: "Comedy Showcase", itemDescription: "Stand-up featuring Pacific Northwest comedians", startTime: date(8, 30, 14, 0), endTime: date(8, 30, 15, 30), category: "Comedy"),
            ScheduleItem(title: "Indie Film Screening", itemDescription: "Curated short films from local filmmakers", startTime: date(8, 31, 11, 0), endTime: date(8, 31, 13, 0), category: "Film"),
            ScheduleItem(title: "Brandi Carlile", itemDescription: "Grammy-winning singer-songwriter", startTime: date(8, 31, 20, 0), endTime: date(8, 31, 21, 30), category: "Music"),
            ScheduleItem(title: "Art Walk", itemDescription: "Guided tour of festival art installations", startTime: date(9, 1, 10, 0), endTime: date(9, 1, 12, 0), category: "Art"),
        ]
        bSchedule[0].stage = bMainStage
        bSchedule[1].stage = bMural
        bSchedule[2].stage = bFisherPavilion
        bSchedule[3].stage = bFisherPavilion
        bSchedule[4].stage = bMainStage
        bSchedule[5].stage = bMural

        for item in bSchedule { item.event = bumbershoot }

        let bPins = [
            MapPin(label: "Main Stage", pinType: .stage, x: 0.5, y: 0.25),
            MapPin(label: "Fisher Pavilion", pinType: .stage, x: 0.3, y: 0.5),
            MapPin(label: "Mural Amphitheatre", pinType: .stage, x: 0.7, y: 0.4),
            MapPin(label: "Restrooms North", pinType: .restroom, x: 0.2, y: 0.2),
            MapPin(label: "Restrooms South", pinType: .restroom, x: 0.8, y: 0.7),
            MapPin(label: "Food Court", pinType: .food, x: 0.5, y: 0.6, pinDescription: "International food vendors"),
            MapPin(label: "First Aid", pinType: .firstAid, x: 0.15, y: 0.45),
            MapPin(label: "Main Entrance", pinType: .exit, x: 0.5, y: 0.9),
        ]
        for pin in bPins { pin.event = bumbershoot }

        // MARK: - Bite of Seattle

        let bite = Event(
            name: "Bite of Seattle",
            slug: "bite-of-seattle",
            eventDescription: "The Pacific Northwest's largest food festival featuring 60+ restaurants, live cooking demos, and entertainment.",
            startDate: date(7, 18),
            endDate: date(7, 20),
            location: "Seattle Center",
            neighborhood: "Lower Queen Anne",
            logoSystemImage: "fork.knife",
            ticketingURL: "https://www.biteofseattle.com",
            category: .fair
        )

        let biteMain = Stage(name: "Main Demo Stage", mapX: 0.5, mapY: 0.3)
        let biteBeer = Stage(name: "Beer Garden Stage", mapX: 0.7, mapY: 0.6)
        biteMain.event = bite
        biteBeer.event = bite

        let biteSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Tom Douglas Cook-Off", itemDescription: "Celebrity chef showdown", startTime: date(7, 18, 12, 0), endTime: date(7, 18, 13, 30), category: "Cooking"),
            ScheduleItem(title: "PNW Wine Tasting", itemDescription: "Sample wines from Washington vineyards", startTime: date(7, 18, 15, 0), endTime: date(7, 18, 17, 0), category: "Tasting"),
            ScheduleItem(title: "Live Jazz", itemDescription: "Smooth jazz in the beer garden", startTime: date(7, 19, 18, 0), endTime: date(7, 19, 20, 0), category: "Music"),
            ScheduleItem(title: "Kids Cooking Class", itemDescription: "Hands-on cooking for ages 6-12", startTime: date(7, 20, 11, 0), endTime: date(7, 20, 12, 0), category: "Family"),
        ]
        biteSchedule[0].stage = biteMain
        biteSchedule[1].stage = biteMain
        biteSchedule[2].stage = biteBeer
        biteSchedule[3].stage = biteMain
        for item in biteSchedule { item.event = bite }

        let bitePins = [
            MapPin(label: "Demo Stage", pinType: .stage, x: 0.5, y: 0.3),
            MapPin(label: "Beer Garden", pinType: .food, x: 0.7, y: 0.6, pinDescription: "21+ with ID"),
            MapPin(label: "Food Row A", pinType: .food, x: 0.3, y: 0.4, pinDescription: "Asian, Mexican, Italian"),
            MapPin(label: "Food Row B", pinType: .food, x: 0.6, y: 0.45, pinDescription: "BBQ, Seafood, Desserts"),
            MapPin(label: "Restrooms", pinType: .restroom, x: 0.15, y: 0.5),
            MapPin(label: "First Aid", pinType: .firstAid, x: 0.85, y: 0.3),
            MapPin(label: "Entry Gate", pinType: .exit, x: 0.5, y: 0.9),
        ]
        for pin in bitePins { pin.event = bite }

        // MARK: - Seattle Pride

        let pride = Event(
            name: "Seattle Pride",
            slug: "seattle-pride",
            eventDescription: "Seattle's annual LGBTQ+ pride celebration with parade, festival, and community events across Capitol Hill and downtown.",
            startDate: date(6, 28),
            endDate: date(6, 29),
            location: "Capitol Hill & Downtown",
            neighborhood: "Capitol Hill",
            logoSystemImage: "heart.fill",
            ticketingURL: "https://www.seattlepride.org",
            category: .community
        )

        let prideMainStage = Stage(name: "Pride Main Stage", mapX: 0.5, mapY: 0.3)
        let prideDance = Stage(name: "Dance Pavilion", mapX: 0.3, mapY: 0.6)
        prideMainStage.event = pride
        prideDance.event = pride

        let prideSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Pride Parade", itemDescription: "March from downtown to Capitol Hill", startTime: date(6, 28, 11, 0), endTime: date(6, 28, 14, 0), category: "Parade"),
            ScheduleItem(title: "Drag Spectacular", itemDescription: "Performances by top Seattle drag artists", startTime: date(6, 28, 16, 0), endTime: date(6, 28, 18, 0), category: "Performance"),
            ScheduleItem(title: "Pride DJ Set", itemDescription: "Dance party on the main stage", startTime: date(6, 28, 20, 0), endTime: date(6, 28, 23, 0), category: "Music"),
            ScheduleItem(title: "Community Rally", itemDescription: "Speakers and community celebration", startTime: date(6, 29, 12, 0), endTime: date(6, 29, 14, 0), category: "Community"),
        ]
        prideSchedule[0].stage = prideMainStage
        prideSchedule[1].stage = prideMainStage
        prideSchedule[2].stage = prideDance
        prideSchedule[3].stage = prideMainStage
        for item in prideSchedule { item.event = pride }

        let pridePins = [
            MapPin(label: "Main Stage", pinType: .stage, x: 0.5, y: 0.3),
            MapPin(label: "Dance Pavilion", pinType: .stage, x: 0.3, y: 0.6),
            MapPin(label: "Food Vendors", pinType: .food, x: 0.65, y: 0.5),
            MapPin(label: "Restrooms", pinType: .restroom, x: 0.2, y: 0.35),
            MapPin(label: "First Aid", pinType: .firstAid, x: 0.8, y: 0.4),
            MapPin(label: "Info Booth", pinType: .custom, x: 0.5, y: 0.85, pinDescription: "Maps, schedules, lost & found"),
        ]
        for pin in pridePins { pin.event = pride }

        // MARK: - Seafair

        let seafair = Event(
            name: "Seafair",
            slug: "seafair",
            eventDescription: "Seattle's month-long summer celebration featuring the Blue Angels, hydroplane races, and community events across the city.",
            startDate: date(7, 4),
            endDate: date(8, 3),
            location: "Lake Washington & Citywide",
            neighborhood: "Rainier Valley",
            logoSystemImage: "airplane",
            ticketingURL: "https://www.seafair.org/tickets",
            category: .festival
        )

        let seafairSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Torchlight Parade", itemDescription: "Illuminated parade through downtown", startTime: date(7, 26, 19, 30), endTime: date(7, 26, 22, 0), category: "Parade"),
            ScheduleItem(title: "Blue Angels Air Show", itemDescription: "US Navy flight demonstration", startTime: date(8, 2, 13, 0), endTime: date(8, 2, 16, 0), category: "Air Show"),
            ScheduleItem(title: "Hydroplane Races", itemDescription: "H1 Unlimited hydroplane racing on Lake Washington", startTime: date(8, 3, 10, 0), endTime: date(8, 3, 17, 0), category: "Racing"),
        ]
        for item in seafairSchedule { item.event = seafair }

        // MARK: - Northwest Folklife

        let folklife = Event(
            name: "Northwest Folklife Festival",
            slug: "nw-folklife",
            eventDescription: "Free community-powered arts and culture festival celebrating the diverse traditions of the Pacific Northwest.",
            startDate: date(5, 23),
            endDate: date(5, 26),
            location: "Seattle Center",
            neighborhood: "Lower Queen Anne",
            logoSystemImage: "guitars",
            category: .festival
        )

        let folkStage = Stage(name: "Fountain Stage", mapX: 0.5, mapY: 0.35)
        let folkNalanda = Stage(name: "Nalanda Stage", mapX: 0.3, mapY: 0.55)
        folkStage.event = folklife
        folkNalanda.event = folklife

        let folkSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Bluegrass Jam", itemDescription: "Open jam session — bring your instrument", startTime: date(5, 23, 11, 0), endTime: date(5, 23, 13, 0), category: "Music"),
            ScheduleItem(title: "World Dance Workshop", itemDescription: "Learn dances from around the globe", startTime: date(5, 24, 14, 0), endTime: date(5, 24, 16, 0), category: "Dance"),
            ScheduleItem(title: "Storytelling Circle", itemDescription: "Oral traditions and folk tales", startTime: date(5, 25, 10, 0), endTime: date(5, 25, 12, 0), category: "Spoken Word"),
        ]
        folkSchedule[0].stage = folkStage
        folkSchedule[1].stage = folkNalanda
        folkSchedule[2].stage = folkStage
        for item in folkSchedule { item.event = folklife }

        let folkPins = [
            MapPin(label: "Fountain Stage", pinType: .stage, x: 0.5, y: 0.35),
            MapPin(label: "Nalanda Stage", pinType: .stage, x: 0.3, y: 0.55),
            MapPin(label: "Craft Market", pinType: .custom, x: 0.7, y: 0.45, pinDescription: "Handmade goods and artisan crafts"),
            MapPin(label: "Food Court", pinType: .food, x: 0.5, y: 0.7),
            MapPin(label: "Restrooms", pinType: .restroom, x: 0.15, y: 0.6),
        ]
        for pin in folkPins { pin.event = folklife }

        // MARK: - PAX West

        let pax = Event(
            name: "PAX West",
            slug: "pax-west",
            eventDescription: "The largest gaming festival in the western US. Tabletop, video games, panels, concerts, and more.",
            startDate: date(8, 29),
            endDate: date(9, 1),
            location: "Washington State Convention Center",
            neighborhood: "Downtown",
            logoSystemImage: "gamecontroller.fill",
            ticketingURL: "https://west.paxsite.com/",
            category: .expo
        )

        let paxMain = Stage(name: "Main Theatre", mapX: 0.5, mapY: 0.25)
        let paxPanels = Stage(name: "Panel Room A", mapX: 0.25, mapY: 0.5)
        paxMain.event = pax
        paxPanels.event = pax

        let paxSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Opening Keynote", itemDescription: "PAX West 2026 kickoff", startTime: date(8, 29, 10, 30), endTime: date(8, 29, 12, 0), category: "Panel"),
            ScheduleItem(title: "Indie Showcase", itemDescription: "Top 20 indie games of the year", startTime: date(8, 30, 13, 0), endTime: date(8, 30, 15, 0), category: "Gaming"),
            ScheduleItem(title: "Tabletop Freeplay", itemDescription: "Open gaming tables — all skill levels welcome", startTime: date(8, 30, 10, 0), endTime: date(8, 30, 22, 0), category: "Tabletop"),
            ScheduleItem(title: "Concert: MC Frontalot", itemDescription: "Nerdcore hip-hop live", startTime: date(8, 31, 21, 0), endTime: date(8, 31, 23, 0), category: "Music"),
        ]
        paxSchedule[0].stage = paxMain
        paxSchedule[1].stage = paxMain
        paxSchedule[2].stage = paxPanels
        paxSchedule[3].stage = paxMain
        for item in paxSchedule { item.event = pax }

        let paxPins = [
            MapPin(label: "Main Theatre", pinType: .stage, x: 0.5, y: 0.25),
            MapPin(label: "Panel Rooms", pinType: .stage, x: 0.25, y: 0.5),
            MapPin(label: "Expo Hall", pinType: .custom, x: 0.6, y: 0.5, pinDescription: "Game demos and exhibitors"),
            MapPin(label: "Tabletop Area", pinType: .custom, x: 0.4, y: 0.7, pinDescription: "Board games and RPGs"),
            MapPin(label: "Food Court", pinType: .food, x: 0.8, y: 0.4),
            MapPin(label: "Restrooms", pinType: .restroom, x: 0.15, y: 0.35),
            MapPin(label: "First Aid", pinType: .firstAid, x: 0.85, y: 0.6),
            MapPin(label: "Main Entrance", pinType: .exit, x: 0.5, y: 0.95),
        ]
        for pin in paxPins { pin.event = pax }

        // MARK: - Emerald City Comic Con

        let eccc = Event(
            name: "Emerald City Comic Con",
            slug: "eccc",
            eventDescription: "The Pacific Northwest's premier comic book and pop culture convention featuring celebrity guests, panels, cosplay, and artist alley.",
            startDate: date(3, 6),
            endDate: date(3, 9),
            location: "Washington State Convention Center",
            neighborhood: "Downtown",
            logoSystemImage: "star.fill",
            ticketingURL: "https://www.emeraldcitycomiccon.com/",
            category: .expo
        )

        let ecccSchedule: [ScheduleItem] = [
            ScheduleItem(title: "Cosplay Contest", itemDescription: "Annual costume competition", startTime: date(3, 8, 18, 0), endTime: date(3, 8, 20, 0), category: "Cosplay"),
            ScheduleItem(title: "Artist Alley Opens", itemDescription: "Meet creators and buy original art", startTime: date(3, 6, 10, 0), endTime: date(3, 6, 18, 0), category: "Art"),
        ]
        for item in ecccSchedule { item.event = eccc }

        // MARK: - Insert everything

        let allEvents = [bumbershoot, bite, pride, seafair, folklife, pax, eccc]
        let allStages = [bMainStage, bFisherPavilion, bMural, biteMain, biteBeer, prideMainStage, prideDance, folkStage, folkNalanda, paxMain, paxPanels]
        let allItems = bSchedule + biteSchedule + prideSchedule + seafairSchedule + folkSchedule + paxSchedule + ecccSchedule
        let allPins = bPins + bitePins + pridePins + folkPins + paxPins

        for event in allEvents { context.insert(event) }
        for stage in allStages { context.insert(stage) }
        for item in allItems { context.insert(item) }
        for pin in allPins { context.insert(pin) }
    }
}
