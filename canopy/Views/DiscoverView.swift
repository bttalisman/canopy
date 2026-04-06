import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedNeighborhood: String?
    @State private var showMapView = false
    @State private var selectedMapEvent: Event?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastFetchedCount: Int?

    private var hasBackend: Bool {
        let url = Secrets.canopyAPIBaseURL
        return !url.isEmpty && url != "YOUR_API_URL_HERE"
    }

    enum TimeFilter: String, CaseIterable, Identifiable {
        case all = "Any Time"
        case thisWeek = "This Week"
        case thisWeekend = "This Weekend"
        case thisMonth = "This Month"

        var id: String { rawValue }
    }

    var neighborhoods: [String] {
        Array(Set(events.filter { $0.isActive && !$0.neighborhood.isEmpty }.map(\.neighborhood))).sorted()
    }

    var filteredEvents: [Event] {
        var result = events.filter { $0.isActive }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.eventDescription.localizedCaseInsensitiveContains(searchText) ||
                $0.neighborhood.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if let neighborhood = selectedNeighborhood {
            result = result.filter { $0.neighborhood == neighborhood }
        }

        let now = Date()
        let calendar = Calendar.current

        switch selectedTimeFilter {
        case .all:
            break
        case .thisWeek:
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now)!
            result = result.filter { $0.startDate <= endOfWeek && $0.endDate >= now }
        case .thisWeekend:
            let weekday = calendar.component(.weekday, from: now)
            // weekday: 1=Sun, 2=Mon, 3=Tue, 4=Wed, 5=Thu, 6=Fri, 7=Sat
            let daysToSaturday: Int
            switch weekday {
            case 1: daysToSaturday = -1  // Sunday → go back to Saturday
            case 7: daysToSaturday = 0   // Already Saturday
            default: daysToSaturday = 7 - weekday  // Mon-Fri → next Saturday
            }
            let saturday = calendar.date(byAdding: .day, value: daysToSaturday, to: now)!
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
            let startOfSaturday = calendar.startOfDay(for: saturday)
            let endOfSunday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday)!
            result = result.filter { $0.startDate <= endOfSunday && $0.endDate >= startOfSaturday }
        case .thisMonth:
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: now)!
            result = result.filter { $0.startDate <= endOfMonth && $0.endDate >= now }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    CanopyPinView(size: 42)
                        .accessibilityHidden(true)

                    HStack(spacing: 6) {
                        Text("Canopy")
                            .font(.system(size: 28, weight: .bold))
                        Text("Seattle")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Canopy Seattle")

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showMapView.toggle()
                            selectedMapEvent = nil
                        }
                    } label: {
                        Image(systemName: showMapView ? "list.bullet" : "map")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(showMapView ? "Show list view" : "Show map view")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search events, venues...", text: $searchText)
                        .onChange(of: searchText) { oldValue, newValue in
                            if newValue.isEmpty && !oldValue.isEmpty {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(10)
                .background(Color(.systemGray5).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.vertical, 10)

                // Filter pills
                VStack(spacing: 8) {
                    // Time filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(TimeFilter.allCases) { filter in
                                Button {
                                    withAnimation { selectedTimeFilter = filter }
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(selectedTimeFilter == filter ? .semibold : .regular)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            Capsule()
                                                .fill(selectedTimeFilter == filter ? Color.green : Color(.systemGray5))
                                        )
                                        .foregroundStyle(selectedTimeFilter == filter ? .white : .primary)
                                        .accessibilityLabel("\(filter.rawValue) filter")
                                        .accessibilityAddTraits(selectedTimeFilter == filter ? .isSelected : [])
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                withAnimation { selectedCategory = nil }
                            } label: {
                                Label("All", systemImage: "square.grid.2x2")
                                    .font(.subheadline)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(selectedCategory == nil ? Color.green.opacity(0.15) : Color(.systemGray6))
                                    )
                                    .foregroundStyle(selectedCategory == nil ? .green : .secondary)
                            }

                            ForEach(EventCategory.allCases) { cat in
                                Button {
                                    withAnimation { selectedCategory = cat }
                                } label: {
                                    Label(cat.rawValue, systemImage: cat.systemImage)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedCategory == cat ? Color.green.opacity(0.15) : Color(.systemGray6))
                                        )
                                        .foregroundStyle(selectedCategory == cat ? .green : .secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    // Neighborhood filter pills
                    if neighborhoods.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Button {
                                    withAnimation { selectedNeighborhood = nil }
                                } label: {
                                    Label("All Areas", systemImage: "mappin.and.ellipse")
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(selectedNeighborhood == nil ? Color.orange.opacity(0.15) : Color(.systemGray6))
                                        )
                                        .foregroundStyle(selectedNeighborhood == nil ? .orange : .secondary)
                                }

                                ForEach(neighborhoods, id: \.self) { hood in
                                    Button {
                                        withAnimation { selectedNeighborhood = hood }
                                    } label: {
                                        Text(hood)
                                            .font(.subheadline)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(
                                                Capsule()
                                                    .fill(selectedNeighborhood == hood ? Color.orange.opacity(0.15) : Color(.systemGray6))
                                            )
                                            .foregroundStyle(selectedNeighborhood == hood ? .orange : .secondary)
                                            .accessibilityLabel("\(hood) neighborhood filter")
                                            .accessibilityAddTraits(selectedNeighborhood == hood ? .isSelected : [])
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 8)

                if showMapView {
                    // Map view
                    DiscoverMapView(
                        events: filteredEvents,
                        selectedEvent: $selectedMapEvent,
                        showDateSlider: selectedTimeFilter == .all
                    )
                    .toolbar(.visible, for: .tabBar)
                } else {
                    // List view
                    ScrollView {
                        VStack(spacing: 16) {
                            if isLoading {
                                ProgressView("Fetching Seattle events...")
                                    .padding(.top, 40)
                            } else if let error = errorMessage {
                                VStack(spacing: 12) {
                                    Label(error, systemImage: "exclamationmark.triangle")
                                        .font(.subheadline)
                                        .foregroundStyle(.orange)
                                        .multilineTextAlignment(.center)

                                    Button("Retry") {
                                        Task { await fetchEvents() }
                                    }
                                    .buttonStyle(.bordered)
                                }
                                .padding(.top, 40)
                                .padding(.horizontal)
                            } else if let count = lastFetchedCount {
                                Text("Imported \(count) new events from Ticketmaster")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                                    .padding(.horizontal)
                            }

                            if filteredEvents.isEmpty && !isLoading && errorMessage == nil {
                                ContentUnavailableView(
                                    "No Events Found",
                                    systemImage: "calendar.badge.exclamationmark",
                                    description: Text(hasBackend
                                        ? "Try adjusting your filters or pull to refresh."
                                        : "Backend not configured.")
                                )
                                .padding(.top, 60)
                            } else {
                                LazyVStack(spacing: 16) {
                                    ForEach(filteredEvents) { event in
                                        NavigationLink(value: event) {
                                            EventCard(event: event)
                                        }
                                        .buttonStyle(.plain)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical, 8)
                        .animation(.easeInOut(duration: 0.25), value: filteredEvents.map(\.id))
                    }
                    .refreshable {
                        await fetchEvents()
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .task {
                // Backfill map data for events missing it (skip events with custom map images)
                for event in events where event.mapPins.isEmpty && event.mapImageURL == nil {
                    VenueMapData.attachMapData(to: event, using: modelContext)
                }

                // Always sync from backend on launch
                await fetchEvents()
            }
        }
    }

    private func fetchEvents() async {
        print("[Fetch] fetchEvents() called, hasBackend=\(hasBackend)")
        isLoading = true
        errorMessage = nil
        lastFetchedCount = nil

        var totalImported = 0

        // 1. Fetch from Canopy backend (schedule items, curated events)
        do {
            print("[Fetch] Calling Canopy API at \(Secrets.canopyAPIBaseURL)")
            let apiEvents = try await CanopyAPIService.shared.fetchEvents()
            print("[Fetch] Got \(apiEvents.count) events from backend")
            for e in apiEvents {
                print("[Fetch]   \(e.name): \(e.scheduleItems?.count ?? 0) schedule, \(e.mapPins?.count ?? 0) pins, \(e.stages?.count ?? 0) stages")
            }
            let count = await CanopyAPIService.shared.importEvents(apiEvents, into: modelContext)
            totalImported += count
            print("[Fetch] Imported \(count) new events")
        } catch let error as CanopyAPIError where error == .notConfigured {
            print("[Fetch] Backend not configured, skipping")
        } catch is CancellationError {
            print("[Fetch] Canopy API cancelled")
            isLoading = false
            return
        } catch {
            print("[Fetch] Canopy API error: \(error.localizedDescription)")
        }

        // 2. Fetch from Ticketmaster (via backend proxy)
        if hasBackend {
            do {
                let formatter = ISO8601DateFormatter()
                let startDT = formatter.string(from: Date())

                let response = try await TicketmasterService.shared.searchEvents(
                    startDateTime: startDT
                )

                let tmEvents = response.embedded?.events ?? []
                let count = await TicketmasterService.shared.importEvents(tmEvents, into: modelContext)
                totalImported += count
            } catch is CancellationError {
                print("[Fetch] Ticketmaster cancelled")
                isLoading = false
                return
            } catch {
                if totalImported == 0 && !events.isEmpty {
                    // Don't show error if we already have cached events
                    print("[Fetch] Ticketmaster error (cached data available): \(error.localizedDescription)")
                } else if totalImported == 0 {
                    errorMessage = error.localizedDescription
                }
            }
        }

        if totalImported > 0 {
            lastFetchedCount = totalImported
            try? await Task.sleep(for: .seconds(3))
            lastFetchedCount = nil
        }

        isLoading = false
    }
}

struct EventCard: View {
    let event: Event

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Event image (if available from API)
            if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipped()
                    case .failure:
                        fallbackHeader
                    case .empty:
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 140)
                            .overlay(ProgressView())
                    @unknown default:
                        fallbackHeader
                    }
                }
            } else {
                fallbackHeader
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.name)
                            .font(.headline)
                            .lineLimit(2)

                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(event.startDate, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.green)

                        if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) {
                            Text("– \(event.endDate, format: .dateTime.month(.abbreviated).day())")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        if let lat = event.latitude, let lng = event.longitude {
                            WeatherBadgeView(latitude: lat, longitude: lng, date: event.startDate)
                        }
                    }
                }

                if !event.eventDescription.isEmpty {
                    Text(event.eventDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack {
                    Label(event.category.rawValue, systemImage: event.category.systemImage)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .clipShape(Capsule())

                    Spacer()

                    if event.ticketingURL != nil {
                        Label("Tickets", systemImage: "ticket")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .padding()
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.name), \(event.category.rawValue) at \(event.location), \(event.startDate.formatted(.dateTime.month(.wide).day()))")
        .accessibilityHint("Double tap to view event details")
    }

    private var categoryColor: Color {
        switch event.category {
        case .festival: return .green
        case .concert: return .purple
        case .fair: return .orange
        case .conference: return .blue
        case .expo: return .cyan
        case .community: return .pink
        }
    }

    private var fallbackHeader: some View {
        ZStack {
            LinearGradient(
                colors: [categoryColor.opacity(0.3), categoryColor.opacity(0.1), Color(.secondarySystemBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: event.logoSystemImage)
                .font(.system(size: 50, weight: .thin))
                .foregroundStyle(categoryColor.opacity(0.2))
        }
        .frame(height: 100)
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
