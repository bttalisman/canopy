import SwiftUI
import SwiftData

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

    var filteredPins: [MapPin] {
        if let type = selectedPinType {
            return event.mapPins.filter { $0.pinType == type }
        }
        return event.mapPins
    }

    var body: some View {
        VStack(spacing: 12) {
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
                // Interactive venue map
                GeometryReader { geo in
                    ZStack {
                        // Background grid
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))

                        // Grid lines
                        Canvas { context, size in
                            let step: CGFloat = 30
                            for x in stride(from: step, to: size.width, by: step) {
                                var path = Path()
                                path.move(to: CGPoint(x: x, y: 0))
                                path.addLine(to: CGPoint(x: x, y: size.height))
                                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                            }
                            for y in stride(from: step, to: size.height, by: step) {
                                var path = Path()
                                path.move(to: CGPoint(x: 0, y: y))
                                path.addLine(to: CGPoint(x: size.width, y: y))
                                context.stroke(path, with: .color(.gray.opacity(0.15)), lineWidth: 0.5)
                            }
                        }

                        // Map pins
                        ForEach(filteredPins) { pin in
                            VenueMapPin(pin: pin)
                                .position(
                                    x: pin.x * geo.size.width,
                                    y: pin.y * geo.size.height
                                )
                        }
                    }
                }
                .frame(height: 350)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Pin legend
                VStack(alignment: .leading, spacing: 8) {
                    Text("Locations")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(filteredPins) { pin in
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

struct VenueMapPin: View {
    let pin: MapPin

    var pinColor: Color {
        switch pin.pinType {
        case .restroom: return .blue
        case .food: return .orange
        case .stage: return .purple
        case .firstAid: return .red
        case .exit: return .green
        case .custom: return .gray
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: pin.pinType.systemImage)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(pinColor)
                .clipShape(Circle())
                .shadow(radius: 2)

            Text(pin.label)
                .font(.system(size: 9, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color(.systemBackground).opacity(0.9))
                .clipShape(RoundedRectangle(cornerRadius: 3))
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
