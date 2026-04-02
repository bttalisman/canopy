import SwiftUI
import SwiftData
import MapKit

struct EventDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var event: Event
    @State private var selectedTab: DetailTab = .schedule

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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Hero header
                if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(16/9, contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                        case .failure:
                            EmptyView()
                        case .empty:
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 200)
                                .overlay(ProgressView())
                        @unknown default:
                            EmptyView()
                        }
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

                    HStack(spacing: 16) {
                        Label(event.location, systemImage: "mappin.and.ellipse")
                        Label(event.neighborhood, systemImage: "building.2")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Text(event.startDate, format: .dateTime.month(.wide).day())
                        Text("–")
                        Text(event.endDate, format: .dateTime.month(.wide).day(.twoDigits).year())
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.green)

                    if let url = event.ticketingURL, let ticketURL = URL(string: url) {
                        Link(destination: ticketURL) {
                            Label("Get Tickets", systemImage: "ticket")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.green)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .padding(.top, 8)

                // Tab picker
                Picker("Section", selection: $selectedTab) {
                    ForEach(DetailTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom)

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
        var items = event.scheduleItems

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
            if !event.stages.isEmpty {
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
                            ScheduleItemRow(item: item, modelContext: modelContext)
                        }
                    }
                }
            }
        }
        .padding(.bottom)
    }
}

struct ScheduleItemRow: View {
    let item: ScheduleItem
    let modelContext: ModelContext

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.startTime, format: .dateTime.hour().minute())
                    .font(.caption)
                    .fontWeight(.semibold)
                Text(item.endTime, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
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
                }

                if let stage = item.stage {
                    Label(stage.name, systemImage: "music.mic")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                toggleSave(item)
            } label: {
                Image(systemName: item.isSaved ? "bookmark.fill" : "bookmark")
                    .foregroundStyle(item.isSaved ? .green : .secondary)
                    .font(.title3)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(item.isCancelled ? Color.red.opacity(0.05) : Color.clear)
        .opacity(item.isCancelled ? 0.7 : 1.0)
    }

    private func toggleSave(_ item: ScheduleItem) {
        if let saved = item.savedByUsers.first {
            modelContext.delete(saved)
        } else {
            let saved = UserSavedItem(scheduleItem: item)
            modelContext.insert(saved)
        }
    }
}

// MARK: - Map Tab

struct EventMapView: View {
    let event: Event
    @State private var selectedPinType: MapPinType?
    @State private var selectedPin: MapPin?
    @State private var mapPosition: MapCameraPosition = .automatic

    var filteredPins: [MapPin] {
        if let type = selectedPinType {
            return event.mapPins.filter { $0.pinType == type }
        }
        return event.mapPins
    }

    // Convert a pin's relative x/y (0–1) to lat/long around the venue center
    func pinCoordinate(_ pin: MapPin) -> CLLocationCoordinate2D {
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
                    Button {
                        selectedPinType = nil
                    } label: {
                        Label("All", systemImage: "map")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedPinType == nil ? Color.green : Color(.systemGray5))
                            .foregroundStyle(selectedPinType == nil ? .white : .primary)
                            .clipShape(Capsule())
                    }
                    ForEach(MapPinType.allCases) { type in
                        Button {
                            selectedPinType = type
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

            if event.mapPins.isEmpty {
                ContentUnavailableView(
                    "No Map Data",
                    systemImage: "map",
                    description: Text("Venue map details haven't been added yet.")
                )
                .padding(.top, 40)
            } else {
                // Real MapKit map with annotation pins
                Map(position: $mapPosition) {
                    UserAnnotation()

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
                }

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

    func pinColor(_ type: MapPinType) -> Color {
        switch type {
        case .restroom: return .blue
        case .food: return .orange
        case .stage: return .purple
        case .firstAid: return .red
        case .exit: return .green
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
                    Text(event.startDate, format: .dateTime.month(.wide).day().year())
                }
                .font(.subheadline)

                HStack {
                    Label("Ends", systemImage: "calendar.badge.checkmark")
                    Spacer()
                    Text(event.endDate, format: .dateTime.month(.wide).day().year())
                }
                .font(.subheadline)
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
