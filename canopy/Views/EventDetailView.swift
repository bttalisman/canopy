import SwiftUI
import SwiftData
import MapKit

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: Event
    @State private var selectedTab: DetailTab = .schedule
    @State private var eventSaved = false

    enum DetailTab: String, CaseIterable, Identifiable {
        case schedule = "Schedule"
        case map = "Map"
        case info = "Info"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .schedule: return "calendar"
            case .map: return "map"
            case .info: return "info.circle"
            }
        }
    }

    private var shareText: String {
        var text = "\(event.name) — \(event.location)"
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        text += "\n\(formatter.string(from: event.startDate))"
        if let url = event.ticketingURL { text += "\n\(url)" }
        text += "\n\nShared via Canopy"
        return text
    }

    private var ticketLabel: String {
        if event.isFree == true { return "Free" }
        if let min = event.priceMin, let max = event.priceMax {
            if min == max { return "Tickets \u{00B7} $\(Int(min))" }
            return "Tickets \u{00B7} $\(Int(min))\u{2013}$\(Int(max))"
        }
        if let min = event.priceMin { return "Tickets \u{00B7} From $\(Int(min))" }
        return "Tickets"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                    CachedAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                    } placeholder: {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay(ProgressView())
                    }
                }

                VStack(spacing: 12) {
                    Image(systemName: event.logoSystemImage)
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                        .frame(width: 90, height: 90)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 22))

                    Text(event.name)
                        .font(.title.bold())
                        .multilineTextAlignment(.center)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            Label(event.location, systemImage: "mappin.and.ellipse")
                            Label(event.neighborhood, systemImage: "building.2")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            Text(event.startDate, format: .dateTime.month(.wide).day().hour().minute())
                            Text("–")
                            Text(event.endDate, format: .dateTime.month(.wide).day().hour().minute().year())
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                        .fixedSize()
                    }

                    if let lat = event.latitude, let lng = event.longitude {
                        WeatherForecastView(
                            latitude: lat, longitude: lng,
                            startDate: event.startDate, endDate: event.endDate
                        )
                    }

                    HStack(spacing: 12) {
                        if let url = event.ticketingURL, let ticketURL = URL(string: url) {
                            Link(destination: ticketURL) {
                                Label(ticketLabel, systemImage: "ticket")
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(Color.green)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityLabel("Get tickets for \(event.name)")
                            .accessibilityHint("Opens ticketing website")
                        }

                        if event.scheduleItems.count != 1 {
                            Button {
                                toggleEventSave()
                            } label: {
                                Label(
                                    eventSaved ? "Saved" : "Save",
                                    systemImage: eventSaved ? "bookmark.fill" : "bookmark"
                                )
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(eventSaved ? Color.green.opacity(0.15) : Color(.systemGray5))
                                .foregroundStyle(eventSaved ? .green : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityLabel(eventSaved ? "Remove \(event.name) from saved events" : "Save \(event.name) to my schedule")
                            .accessibilityAddTraits(eventSaved ? .isSelected : [])
                        }

                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 44)
                                .padding(.vertical, 12)
                                .background(Color(.systemGray5))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
                .padding(.top, 8)

                // Tab picker (only show if more than one tab has content)
                if availableTabs.count > 1 {
                    Picker("Section", selection: $selectedTab) {
                        ForEach(availableTabs) { tab in
                            Label(tab.rawValue, systemImage: tab.systemImage)
                                .tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom)
                }

                // Tab content
                switch selectedTab {
                case .schedule:
                    EventScheduleView(event: event)
                case .map:
                    EventMapView(event: event)
                case .info:
                    EventInfoView(event: event)
                }
            }
        }
        .navigationTitle(event.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkEventSaved()
            if !availableTabs.contains(selectedTab) {
                selectedTab = availableTabs.first ?? .info
            }
        }
    }

    private var hasSchedule: Bool { !event.scheduleItems.isEmpty }
    private var hasMap: Bool {
        !event.mapPins.isEmpty
            || event.mapImageURL != nil
            || (event.latitude != nil && event.longitude != nil)
    }

    private var availableTabs: [DetailTab] {
        var tabs: [DetailTab] = []
        if hasSchedule { tabs.append(.schedule) }
        if hasMap { tabs.append(.map) }
        tabs.append(.info) // always available
        return tabs
    }

    private func checkEventSaved() {
        let eventId = event.id
        let descriptor = FetchDescriptor<UserSavedItem>(predicate: #Predicate {
            $0.event?.id == eventId
        })
        eventSaved = ((try? modelContext.fetch(descriptor))?.isEmpty == false)
    }

    private func toggleEventSave() {
        if eventSaved {
            let eventId = event.id
            let descriptor = FetchDescriptor<UserSavedItem>(predicate: #Predicate {
                $0.event?.id == eventId
            })
            if let items = try? modelContext.fetch(descriptor) {
                for item in items { modelContext.delete(item) }
            }
            eventSaved = false
        } else {
            let saved = UserSavedItem(event: event)
            modelContext.insert(saved)
            try? modelContext.save()
            eventSaved = true
        }
        NotificationManager.shared.syncReminders(context: modelContext)
    }
}

// MARK: - Schedule Tab

struct EventScheduleView: View {
    @Environment(\.modelContext) private var modelContext
    let event: Event
    @State private var selectedStage: Stage?
    @State private var selectedCategory: String?

    var categories: [String] {
        Array(Set(event.scheduleItems.map(\.category))).sorted()
    }

    var groupedItems: [(Date, [ScheduleItem])] {
        let now = Date()
        var items = event.scheduleItems.filter { $0.endTime >= now }

        if let stage = selectedStage {
            items = items.filter { $0.stage?.id == stage.id }
        }
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        items.sort { $0.startTime < $1.startTime }

        let calendar = Calendar.current
        let grouped = Dictionary(grouping: items) { item in
            calendar.startOfDay(for: item.startTime)
        }

        return grouped.sorted { $0.key < $1.key }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if event.stages.count > 1 && event.scheduleItems.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedStage = nil
                        } label: {
                            Text("All Stages")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedStage == nil ? Color.green : Color(.systemGray5))
                                .foregroundStyle(selectedStage == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        ForEach(event.stages) { stage in
                            Button {
                                selectedStage = stage
                            } label: {
                                Text(stage.name)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedStage?.id == stage.id ? Color.green : Color(.systemGray5))
                                    .foregroundStyle(selectedStage?.id == stage.id ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if categories.count > 1 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button {
                            selectedCategory = nil
                        } label: {
                            Text("All")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedCategory == nil ? Color.purple.opacity(0.8) : Color(.systemGray5))
                                .foregroundStyle(selectedCategory == nil ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        ForEach(categories, id: \.self) { cat in
                            Button {
                                selectedCategory = cat
                            } label: {
                                Text(cat)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == cat ? Color.purple.opacity(0.8) : Color(.systemGray5))
                                    .foregroundStyle(selectedCategory == cat ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }

            if groupedItems.isEmpty {
                ContentUnavailableView(
                    "No Sessions",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("No schedule items match your filters.")
                )
                .padding(.top, 40)
            } else {
                ForEach(groupedItems, id: \.0) { day, items in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        ForEach(items) { item in
                            ScheduleItemRow(item: item)
                        }
                    }
                }
            }
        }
        .padding(.bottom)
    }
}

struct ScheduleItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: ScheduleItem
    @State private var saved: Bool = false
    @State private var showingPerformer = false

    private var hasPerformer: Bool {
        item.performerName != nil || item.performerBio != nil || item.performerImageURL != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top row: time range + bookmark
            HStack {
                Label {
                    Text("\(item.startTime, format: .dateTime.hour().minute()) – \(item.endTime, format: .dateTime.hour().minute())")
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.caption)
                .foregroundStyle(.green)

                if let stage = item.stage {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Label(stage.name, systemImage: "music.mic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    toggleSave()
                } label: {
                    Image(systemName: saved ? "bookmark.fill" : "bookmark")
                        .foregroundStyle(saved ? .green : .secondary)
                        .font(.body)
                        .frame(width: 36, height: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(saved ? "Remove \(item.title) from schedule" : "Save \(item.title) to schedule")
                .accessibilityAddTraits(saved ? .isSelected : [])
            }

            // Title
            HStack {
                Text(item.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .strikethrough(item.isCancelled)

                if item.isCancelled {
                    Text("CANCELLED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .clipShape(Capsule())
                }

                if hasPerformer {
                    Spacer()
                    Image(systemName: "person.crop.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Description
            if !item.itemDescription.isEmpty {
                Text(item.itemDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .opacity(item.isCancelled ? 0.7 : 1.0)
        .onTapGesture {
            if hasPerformer { showingPerformer = true }
        }
        .onAppear {
            saved = item.isSaved
        }
        .sheet(isPresented: $showingPerformer) {
            NavigationStack {
                PerformerProfileView(item: item)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showingPerformer = false }
                        }
                    }
            }
        }
    }

    private func toggleSave() {
        if let existing = item.savedByUsers.first {
            item.savedByUsers.removeAll()
            modelContext.delete(existing)
            try? modelContext.save()
            saved = false
            NotificationManager.shared.removeReminder(for: item)
        } else {
            let newSave = UserSavedItem(scheduleItem: item)
            modelContext.insert(newSave)
            try? modelContext.save()
            saved = true
            NotificationManager.shared.scheduleReminder(for: item)
            // Check for conflicts with other saved items
            checkConflicts()
        }
        // Sync push notification registration with backend
        NotificationManager.shared.syncReminders(context: modelContext)
    }

    private func checkConflicts() {
        let descriptor = FetchDescriptor<UserSavedItem>()
        guard let allSaved = try? modelContext.fetch(descriptor) else { return }
        let otherItems = allSaved.compactMap(\.scheduleItem).filter { $0.id != item.id && !$0.isCancelled }

        for other in otherItems {
            if item.startTime < other.endTime && other.startTime < item.endTime {
                NotificationManager.shared.scheduleConflictAlert(item1: item, item2: other)
            }
        }
    }
}

// MARK: - Map Tab

struct EventMapView: View {
    let event: Event
    @State private var selectedPinType: MapPinType?
    @State private var selectedPin: MapPin?
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var streetClosures: [StreetClosure] = []
    @State private var useGoogleMaps = false
    @State private var showSatellite = false
    @State private var showBoundary = true
    @State private var recenterTrigger = 0
    @State private var boundaryCoords: [CLLocationCoordinate2D] = []
    @State private var boundaryLoaded = false

    var availablePinTypes: [MapPinType] {
        let types = Set(event.mapPins.map(\.pinType))
        return MapPinType.allCases.filter { types.contains($0) }
    }

    var filteredPins: [MapPin] {
        guard let type = selectedPinType else { return [] }
        return event.mapPins.filter { $0.pinType == type }
    }

    // Convert a pin's relative x/y (0–1) to lat/long around the venue center.
    // If the pin already has real lat/lng (placed via the Apple Maps editor),
    // use that directly.
    func pinCoordinate(_ pin: MapPin) -> CLLocationCoordinate2D {
        if let lat = pin.latitude, let lon = pin.longitude {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }

        let venue = VenueMapData.findVenue(for: event.location)
        let span = venue?.mapSpan ?? 0.004
        let centerLat = event.latitude ?? venue?.latitude ?? 47.6062
        let centerLon = event.longitude ?? venue?.longitude ?? -122.3321

        // Map x (0–1) to longitude offset, y (0–1) to latitude offset
        // y=0 is top (north), y=1 is bottom (south)
        let lat = centerLat + (0.5 - pin.y) * span
        let lon = centerLon + (pin.x - 0.5) * span

        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(availablePinTypes, id: \.self) { type in
                        Button {
                            selectedPinType = selectedPinType == type ? nil : type
                        } label: {
                            Label(type.rawValue, systemImage: type.systemImage)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(selectedPinType == type ? Color.green : Color(.systemGray5))
                                .foregroundStyle(selectedPinType == type ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal)
            }

            if event.mapImageURL == nil
                && (event.latitude == nil || event.longitude == nil) {
                ContentUnavailableView(
                    "No Map Data",
                    systemImage: "map",
                    description: Text("Venue map details haven't been added yet.")
                )
                .padding(.top, 40)
            } else {
                // "View Venue Map" link when a custom map image is available
                if let mapImageURL = event.mapImageURL, let url = URL(string: mapImageURL) {
                    Link(destination: url) {
                        Label("View Venue Map", systemImage: "map.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(
                                        colors: [Color.leafLight.opacity(0.35), Color.leafDeep.opacity(0.20)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                            )
                            .foregroundStyle(Color.leafDeep)
                    }
                    .padding(.horizontal)
                }
                // Google Maps
                ZStack(alignment: .topTrailing) {
                    GoogleMapView(
                        latitude: mapCenter.lat,
                        longitude: mapCenter.lng,
                        span: VenueMapData.findVenue(for: event.location)?.mapSpan ?? 0.004,
                        markers: googleMapMarkers,
                        isSatellite: showSatellite,
                        boundaryCoords: showBoundary ? boundaryCoords : [],
                        recenterTrigger: recenterTrigger
                    )
                    .frame(height: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    VStack(spacing: 6) {
                        Button {
                            showSatellite.toggle()
                        } label: {
                            Image(systemName: showSatellite ? "map.fill" : "globe.americas.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Button {
                            showBoundary.toggle()
                        } label: {
                            Image(systemName: "square.dashed")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(showBoundary ? .green : .white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        Button {
                            recenterTrigger += 1
                        } label: {
                            Image(systemName: "scope")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 32, height: 32)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                    .padding(8)
                }
                .padding(.horizontal)

                // Apple Maps (kept for future use, currently hidden)
                if false {
                // MapKit map with annotation pins
                Map(position: $mapPosition) {
                    UserAnnotation()

                    // If the event has no pins of its own, show the venue
                    // itself as a marker so the user has something to anchor on.
                    if filteredPins.isEmpty,
                       let lat = event.latitude, let lon = event.longitude {
                        Marker(event.location, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(Color.leafDeep)
                    }

                    // Street closures (orange polylines)
                    ForEach(streetClosures) { closure in
                        MapPolyline(coordinates: closure.clCoordinates)
                            .stroke(.orange.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                    }

                    ForEach(filteredPins) { pin in
                        Annotation(pin.label, coordinate: pinCoordinate(pin)) {
                            Button {
                                selectedPin = pin
                            } label: {
                                Image(systemName: pin.pinType.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(pinColor(pin.pinType))
                                    .clipShape(Circle())
                                    .shadow(radius: 2)
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .including([.restaurant, .restroom, .parking])))
                .frame(height: 380)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                .onAppear {
                    LocationManager.shared.requestPermission()
                    let venue = VenueMapData.findVenue(for: event.location)
                    let centerLat = event.latitude ?? venue?.latitude ?? 47.6062
                    let centerLon = event.longitude ?? venue?.longitude ?? -122.3321
                    let span = venue?.mapSpan ?? 0.004
                    mapPosition = .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                        span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
                    ))

                    // Fetch nearby street closures for this event's date window.
                    Task {
                        do {
                            streetClosures = try await StreetClosureService.shared.fetch(
                                near: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                                startDate: event.startDate,
                                endDate: event.endDate
                            )
                        } catch {
                            streetClosures = []
                        }
                    }
                }
                } // end Apple Maps else

                // Selected pin detail
                if let pin = selectedPin {
                    HStack(spacing: 12) {
                        Image(systemName: pin.pinType.systemImage)
                            .font(.title3)
                            .foregroundStyle(pinColor(pin.pinType))
                            .frame(width: 36, height: 36)
                            .background(pinColor(pin.pinType).opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(pin.label)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if !pin.pinDescription.isEmpty {
                                Text(pin.pinDescription)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text(pin.pinType.rawValue)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }

                        Spacer()

                        Button {
                            selectedPin = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
                    .padding(.horizontal)
                }

                // Pin legend
                if !filteredPins.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locations")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(filteredPins) { pin in
                        Button {
                            selectedPin = pin
                            // Pan map to the selected pin
                            let coord = pinCoordinate(pin)
                            let venue = VenueMapData.findVenue(for: event.location)
                            let span = venue?.mapSpan ?? 0.004
                            withAnimation {
                                mapPosition = .region(MKCoordinateRegion(
                                    center: coord,
                                    span: MKCoordinateSpan(latitudeDelta: span * 0.5, longitudeDelta: span * 0.5)
                                ))
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: pin.pinType.systemImage)
                                    .foregroundStyle(pinColor(pin.pinType))
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(pin.label)
                                        .font(.subheadline)
                                    if !pin.pinDescription.isEmpty {
                                        Text(pin.pinDescription)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(pin.pinType.rawValue)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom)
                }
            }
        }
        .onAppear {
            if !boundaryLoaded { loadBoundary() }
        }
    }

    /// Center of the boundary polygon, if available.
    private var boundaryCenter: (lat: Double, lng: Double)? {
        guard !boundaryCoords.isEmpty else { return nil }
        let avgLat = boundaryCoords.map(\.latitude).reduce(0, +) / Double(boundaryCoords.count)
        let avgLng = boundaryCoords.map(\.longitude).reduce(0, +) / Double(boundaryCoords.count)
        return (avgLat, avgLng)
    }

    /// Check if a point is inside the boundary polygon (ray casting).
    private func pointInBoundary(lat: Double, lng: Double) -> Bool {
        guard boundaryCoords.count >= 3 else { return true }
        var inside = false
        var j = boundaryCoords.count - 1
        for i in 0..<boundaryCoords.count {
            let yi = boundaryCoords[i].latitude, xi = boundaryCoords[i].longitude
            let yj = boundaryCoords[j].latitude, xj = boundaryCoords[j].longitude
            if ((yi > lat) != (yj > lat)) &&
                (lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
                inside = !inside
            }
            j = i
        }
        return inside
    }

    /// Map center: use boundary center if event coords are outside the boundary.
    private var mapCenter: (lat: Double, lng: Double) {
        let eventLat = event.latitude ?? 47.6062
        let eventLng = event.longitude ?? -122.3321

        if !boundaryCoords.isEmpty,
           !pointInBoundary(lat: eventLat, lng: eventLng),
           let center = boundaryCenter {
            return center
        }
        return (eventLat, eventLng)
    }

    private var googleMapMarkers: [(lat: Double, lng: Double, title: String, color: UIColor)] {
        if filteredPins.isEmpty {
            return [(lat: mapCenter.lat, lng: mapCenter.lng, title: event.location, color: UIColor(Color.leafDeep))]
        }
        return filteredPins.map { pin in
            let coord = pinCoordinate(pin)
            return (lat: coord.latitude, lng: coord.longitude, title: pin.label, color: UIColor(pinColor(pin.pinType)))
        }
    }

    private func loadBoundary() {
        print("[Boundary] Loading for event: \(event.name), location: \(event.location)")
        print("[Boundary] Event coords: \(event.latitude ?? 0), \(event.longitude ?? 0)")

        Task {
            // 1. Try API venue-boundaries endpoint (admin-defined venues + legacy)
            do {
                let apiBoundaries = try await CanopyAPIService.shared.fetchVenueBoundaries()
                print("[Boundary] Fetched \(apiBoundaries.count) venue boundaries from API")
                for b in apiBoundaries {
                    print("[Boundary]   - \(b.venueName): \(b.coordinates.count) pts")
                }
                let locationLower = event.location.lowercased()
                print("[Boundary] Matching against location: '\(locationLower)'")
                if let match = apiBoundaries.first(where: { venue in
                    let a = venue.venueName.lowercased()
                    if locationLower.contains(a) || a.contains(locationLower) { return true }
                    return (venue.aliases ?? []).contains { $0.lowercased() == locationLower }
                }) {
                    print("[Boundary] Match found: \(match.venueName) (\(match.coordinates.count) points)")
                    await MainActor.run {
                        boundaryCoords = match.coordinates.map {
                            CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng)
                        }
                        boundaryLoaded = true
                    }
                    return
                } else {
                    print("[Boundary] No match found in API boundaries")
                }
            } catch {
                print("[Boundary] Failed to fetch venue boundaries: \(error)")
            }

            // 3. Check VenueMapData (hardcoded)
            if let venue = VenueMapData.findVenue(for: event.location),
               !venue.boundaryCoords.isEmpty {
                print("[Boundary] Using VenueMapData boundary (\(venue.boundaryCoords.count) points)")
                await MainActor.run {
                    boundaryCoords = venue.boundaryCoords.map {
                        CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1)
                    }
                    boundaryLoaded = true
                }
                return
            }

            // 4. Fallback: Google Geocoding API
            print("[Boundary] Falling back to Geocoding API")
            let address = "\(event.location), \(CityConfig.cityDisplayName), WA"
            if let bounds = await GeocodingService.fetchBounds(for: address) {
                await MainActor.run {
                    boundaryCoords = bounds.coordinates
                    boundaryLoaded = true
                    print("[Boundary] Loaded \(boundaryCoords.count) coords from geocoding")
                }
            } else {
                print("[Boundary] Geocoding returned no results")
            }
        }
    }

    func pinColor(_ type: MapPinType) -> Color {
        switch type {
        case .restroom: return .blue
        case .food: return .orange
        case .stage: return .purple
        case .firstAid: return .red
        case .exit: return .green
        case .wifi: return .cyan
        case .accessible: return .indigo
        case .atm: return .yellow
        case .parking: return .blue
        case .info: return .teal
        case .giftShop: return .pink
        case .bus: return .green
        case .custom: return .gray
        }
    }
}

// MARK: - Info Tab

struct EventInfoView: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("About")
                    .font(.headline)
                Text(event.eventDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.headline)

                Label(event.location, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)

                Label(event.neighborhood, systemImage: "building.2")
                    .font(.subheadline)

                Label(event.category.rawValue, systemImage: event.category.systemImage)
                    .font(.subheadline)

                HStack {
                    Label("Starts", systemImage: "calendar")
                    Spacer()
                    Text(event.startDate, format: .dateTime.month(.wide).day().year().hour().minute())
                }
                .font(.subheadline)

                HStack {
                    Label("Ends", systemImage: "calendar.badge.checkmark")
                    Spacer()
                    Text(event.endDate, format: .dateTime.month(.wide).day().year().hour().minute())
                }
                .font(.subheadline)
            }

            if let lat = event.latitude, let lng = event.longitude {
                Divider()
                RideShareView(venueName: event.location, venueLatitude: lat, venueLongitude: lng)

                Divider()
                TransitDirectionsView(venueName: event.location, venueLatitude: lat, venueLongitude: lng)
            }

            if let url = event.ticketingURL, let ticketURL = URL(string: url) {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tickets")
                        .font(.headline)

                    Link(destination: ticketURL) {
                        Label("Buy Tickets", systemImage: "ticket")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Stats")
                    .font(.headline)

                HStack(spacing: 20) {
                    StatBox(value: "\(event.stages.count)", label: "Stages", icon: "music.mic")
                    StatBox(value: "\(event.scheduleItems.count)", label: "Sessions", icon: "list.bullet")
                    StatBox(value: "\(event.mapPins.count)", label: "Locations", icon: "mappin")
                }
            }
        }
        .padding()
    }
}

struct StatBox: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.green)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
