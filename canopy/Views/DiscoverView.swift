import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var events: [Event]
    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var selectedNeighborhoods: Set<String> = []
    @State private var freeOnly: Bool = false
    @State private var accessibleOnly: Bool = false
    @State private var showMapView = false
    @State private var selectedMapEvent: Event?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastFetchedCount: Int?
    @FocusState private var searchFieldFocused: Bool
    @State private var filterPillsCollapsed: Bool = true
    @State private var expandedNeighborhoodGroup: String?
    @AppStorage("eventSortOrder") private var eventSortOrder = 0
    @ObservedObject private var locationManager = LocationManager.shared
    @State private var scrollMetrics = ScrollMetrics(offset: 0, contentHeight: 0)
    @State private var viewportHeight: CGFloat = 0

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

    struct NeighborhoodGroupView: Identifiable {
        let label: String
        let hoods: [String]
        let color: Color
        var id: String { label }
    }

    var groupedNeighborhoods: [NeighborhoodGroupView] {
        let groups = CityConfig.neighborhoodGroups
        if groups.isEmpty {
            return [NeighborhoodGroupView(label: CityConfig.cityDisplayName, hoods: neighborhoods, color: .orange)]
        }
        var result: [NeighborhoodGroupView] = []
        for group in groups {
            let matching = neighborhoods.filter { group.members.contains($0) }
            if !matching.isEmpty {
                result.append(NeighborhoodGroupView(label: group.label, hoods: matching, color: group.color))
            }
        }
        let allGrouped = Set(groups.flatMap(\.members))
        let ungrouped = neighborhoods.filter { !allGrouped.contains($0) }
        if !ungrouped.isEmpty {
            result.append(NeighborhoodGroupView(label: "Other", hoods: ungrouped, color: .orange))
        }
        return result
    }

    var filteredEvents: [Event] {
        var result = events.filter { $0.isActive && $0.city == CityConfig.citySlug }

        if freeOnly {
            result = result.filter { $0.isFree == true }
        }
        if accessibleOnly {
            result = result.filter { $0.isAccessible == true }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.eventDescription.localizedCaseInsensitiveContains(searchText) ||
                $0.neighborhood.localizedCaseInsensitiveContains(searchText) ||
                $0.location.localizedCaseInsensitiveContains(searchText) ||
                $0.slug.localizedCaseInsensitiveContains(searchText)
            }
        }

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !selectedNeighborhoods.isEmpty {
            result = result.filter { selectedNeighborhoods.contains($0.neighborhood) }
        }

        let now = Date()
        let calendar = Calendar.current

        switch selectedTimeFilter {
        case .all:
            result = result.filter { $0.endDate >= now }
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

        if eventSortOrder == 1 {
            result.sort { a, b in
                let distA = a.latitude.flatMap { lat in a.longitude.flatMap { lng in locationManager.distanceTo(latitude: lat, longitude: lng) } } ?? .infinity
                let distB = b.latitude.flatMap { lat in b.longitude.flatMap { lng in locationManager.distanceTo(latitude: lat, longitude: lng) } } ?? .infinity
                return distA < distB
            }
        } else {
            result.sort { $0.startDate < $1.startDate }
        }

        return result
    }

    private var isSearching: Bool { !searchText.isEmpty }
    private var pillsHidden: Bool { filterPillsCollapsed }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Image("TwoLeaves")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 63)
                        .accessibilityHidden(true)

                    HStack(spacing: 6) {
                        Text("Canopy")
                            .font(.system(size: 28, weight: .bold))
                        Text(CityConfig.cityDisplayName)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: CityConfig.accentGradientColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(CityConfig.appTitle)

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showMapView.toggle()
                            selectedMapEvent = nil
                        }
                    } label: {
                        Image(systemName: showMapView ? "list.bullet" : "map")
                            .font(.title3)
                            .foregroundStyle(Color.leafDeep)
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
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($searchFieldFocused)
                        .submitLabel(.search)
                        .onSubmit { searchFieldFocused = false }
                    if !searchText.isEmpty || searchFieldFocused {
                        Button {
                            searchText = ""
                            searchFieldFocused = false
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

                // Filter pills — hidden while searching or manually collapsed
                if !pillsHidden {
                VStack(spacing: 2) {
                    LeafyDivider()
                        .padding(.horizontal)
                        .padding(.vertical, 0)

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
                                                .fill(
                                                    selectedTimeFilter == filter
                                                        ? AnyShapeStyle(LinearGradient(
                                                            colors: [Color.indigo.opacity(0.35), Color.indigo.opacity(0.15)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing))
                                                        : AnyShapeStyle(Color(.systemGray6))
                                                )
                                        )
                                        .foregroundStyle(selectedTimeFilter == filter ? .indigo : .secondary)
                                        .accessibilityLabel("\(filter.rawValue) filter")
                                        .accessibilityAddTraits(selectedTimeFilter == filter ? .isSelected : [])
                                }
                            }

                            // Free toggle
                            Button {
                                withAnimation { freeOnly.toggle() }
                            } label: {
                                Label("Free", systemImage: "tag")
                                    .font(.subheadline)
                                    .fontWeight(freeOnly ? .semibold : .regular)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                freeOnly
                                                    ? AnyShapeStyle(LinearGradient(
                                                        colors: [Color.leafMid, Color.leafDeep],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                                                    : AnyShapeStyle(Color(.systemGray5))
                                            )
                                    )
                                    .foregroundStyle(freeOnly ? .white : .primary)
                                    .accessibilityLabel("Free events filter")
                                    .accessibilityAddTraits(freeOnly ? .isSelected : [])
                            }

                            // Accessibility toggle
                            Button {
                                withAnimation { accessibleOnly.toggle() }
                            } label: {
                                Label("Accessible", systemImage: "figure.roll")
                                    .font(.subheadline)
                                    .fontWeight(accessibleOnly ? .semibold : .regular)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(
                                                accessibleOnly
                                                    ? AnyShapeStyle(LinearGradient(
                                                        colors: [Color.leafMid, Color.leafDeep],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                                                    : AnyShapeStyle(Color(.systemGray5))
                                            )
                                    )
                                    .foregroundStyle(accessibleOnly ? .white : .primary)
                                    .accessibilityLabel("Wheelchair accessible filter")
                                    .accessibilityAddTraits(accessibleOnly ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal)
                    }

                    TwoLeavesIconDivider()
                        .padding(.horizontal)
                        .padding(.vertical, 0)

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
                                            .fill(
                                                selectedCategory == nil
                                                    ? AnyShapeStyle(LinearGradient(
                                                        colors: [Color.leafLight.opacity(0.35), Color.leafDeep.opacity(0.20)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                                                    : AnyShapeStyle(Color(.systemGray6))
                                            )
                                    )
                                    .foregroundStyle(selectedCategory == nil ? Color.leafDeep : .secondary)
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
                                                .fill(
                                                    selectedCategory == cat
                                                        ? AnyShapeStyle(LinearGradient(
                                                            colors: [Color.leafLight.opacity(0.35), Color.leafDeep.opacity(0.20)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing))
                                                        : AnyShapeStyle(Color(.systemGray6))
                                                )
                                        )
                                        .foregroundStyle(selectedCategory == cat ? Color.leafDeep : .secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Neighborhood filter
                    if neighborhoods.count > 1 {
                        ThreeLeavesDivider()
                            .padding(.horizontal)
                            .padding(.vertical, 0)

                        ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Show selected neighborhood/region pills
                                ForEach(Array(selectedNeighborhoods).sorted(), id: \.self) { selected in
                                    selectedNeighborhoodPill(selected)
                                }

                                if !selectedNeighborhoods.isEmpty {
                                    Color.clear.frame(width: 1).id("selectedNeighborhood")
                                }

                                // Region group pills
                                ForEach(groupedNeighborhoods, id: \.label) { group in
                                    regionPillButton(group)
                                }

                                Color.clear.frame(width: 1).id("neighborhoodTrailing")
                            }
                            .padding(.horizontal)
                        }
                        .onChange(of: selectedNeighborhoods) { _, newValue in
                            if !newValue.isEmpty {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo("selectedNeighborhood", anchor: .leading)
                                }
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        } // end ScrollViewReader

                        // Expanded neighborhood list
                        if let expanded = expandedNeighborhoodGroup,
                           let group = groupedNeighborhoods.first(where: { $0.label == expanded }) {
                            VStack(spacing: 8) {
                                regionSelectAllButton(group)

                            HStack(alignment: .top, spacing: 8) {
                                let midpoint = (group.hoods.count + 1) / 2
                                VStack(spacing: 8) {
                                    ForEach(group.hoods.prefix(midpoint), id: \.self) { hood in
                                        neighborhoodGridButton(hood, color: group.color)
                                    }
                                }
                                VStack(spacing: 8) {
                                    ForEach(group.hoods.suffix(from: midpoint), id: \.self) { hood in
                                        neighborhoodGridButton(hood, color: group.color)
                                    }
                                }
                            }
                            } // end VStack
                            .padding(.top, 6)
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                            .background(Color(.systemBackground))
                            .clipped()
                            .transition(.opacity)
                        }
                    }

                } // end VStack
                .transition(.opacity.combined(with: .move(edge: .top)))
                } // end if !pillsHidden

                // Drawer handle — always visible
                Button {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        filterPillsCollapsed.toggle()
                    }
                } label: {
                    ZStack {
                        SixLeavesDivider()
                            .rotationEffect(.degrees(pillsHidden ? 720 : 0))
                            .animation(.easeInOut(duration: 0.5), value: pillsHidden)
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                if filterPillsCollapsed {
                                    Text("filters")
                                        .font(.system(size: 11, weight: .regular))
                                        .foregroundStyle(Color.leafDeep)
                                        .transition(.move(edge: .trailing).combined(with: .opacity))
                                }
                                Image(systemName: filterPillsCollapsed ? "chevron.down" : "chevron.up")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.leafDeep)
                            }
                            .padding(.trailing, 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.top, 2)
                .padding(.bottom, 4)
                .accessibilityLabel(filterPillsCollapsed ? "Show filters" : "Hide filters")

                if showMapView {
                    // Map view
                    DiscoverMapView(
                        events: filteredEvents,
                        allEvents: events,
                        selectedEvent: $selectedMapEvent,
                        showDateSlider: selectedTimeFilter == .all,
                        selectedNeighborhood: selectedNeighborhoods.first
                    )
                    .toolbar(.visible, for: .tabBar)
                } else {
                    // List view with custom leaf-themed scroll indicator
                    GeometryReader { viewportGeo in
                        ZStack(alignment: .topTrailing) {
                            ScrollView {
                                VStack(spacing: 16) {
                                    if isLoading && events.isEmpty {
                                        ProgressView(CityConfig.eventsLoadingMessage)
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
                                            .foregroundStyle(Color.leafDeep)
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
                            .scrollIndicators(.hidden)
                            .scrollDismissesKeyboard(.immediately)
                            .refreshable {
                                await Task { @MainActor in
                                    await fetchEvents()
                                }.value
                            }
                            .modifier(ScrollMetricsTracker(viewportHeight: viewportGeo.size.height) { metrics, vh in
                                scrollMetrics = metrics
                                viewportHeight = vh
                            })

                            LeafScrollIndicator(
                                scrollOffset: scrollMetrics.offset,
                                contentHeight: scrollMetrics.contentHeight,
                                viewportHeight: viewportHeight
                            )
                            .padding(.trailing, 4)
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.5), value: pillsHidden)
            .onChange(of: isSearching) { _, searching in
                withAnimation(.easeInOut(duration: 0.5)) {
                    filterPillsCollapsed = searching
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
                await Task { @MainActor in
                    await fetchEvents()
                }.value
            }
        }
    }

    private func regionPillButton(_ group: NeighborhoodGroupView) -> some View {
        let isExpanded = expandedNeighborhoodGroup == group.label
        let regionSelected = Set(group.hoods).isSubset(of: selectedNeighborhoods)
        let isActive = isExpanded || regionSelected
        let chevron = isExpanded ? "chevron.up" : "chevron.down"
        let bgStyle: AnyShapeStyle = isActive
            ? AnyShapeStyle(LinearGradient(
                colors: [group.color.opacity(0.25), group.color.opacity(0.10)],
                startPoint: .topLeading, endPoint: .bottomTrailing))
            : AnyShapeStyle(Color(.systemGray6))
        let fgColor: Color = isActive ? group.color : .secondary

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                expandedNeighborhoodGroup = isExpanded ? nil : group.label
            }
        } label: {
            HStack(spacing: 4) {
                Text(group.label)
                Image(systemName: chevron)
                    .font(.caption2)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(bgStyle))
            .foregroundStyle(fgColor)
        }
    }

    private func selectedNeighborhoodPill(_ name: String) -> some View {
        let pillColor = CityConfig.groupColor(for: name)
        let bg = LinearGradient(
            colors: [pillColor.opacity(0.35), pillColor.opacity(0.15)],
            startPoint: .topLeading, endPoint: .bottomTrailing)

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                _ = selectedNeighborhoods.remove(name)
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(bg))
            .foregroundStyle(pillColor)
        }
        .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private func regionSelectAllButton(_ group: NeighborhoodGroupView) -> some View {
        let hoodSet = Set(group.hoods)
        let allSelected = hoodSet.isSubset(of: selectedNeighborhoods)
        let title = allSelected ? "Deselect All \(group.label)" : "Select All \(group.label)"

        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if allSelected {
                    selectedNeighborhoods.subtract(hoodSet)
                } else {
                    selectedNeighborhoods.formUnion(hoodSet)
                }
                expandedNeighborhoodGroup = nil
            }
        } label: {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [group.color.opacity(0.25), group.color.opacity(0.10)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .foregroundStyle(group.color)
        }
    }

    private func neighborhoodGridButton(_ hood: String, color: Color = .orange) -> some View {
        let isSelected = selectedNeighborhoods.contains(hood)
        return Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if isSelected {
                    selectedNeighborhoods.remove(hood)
                } else {
                    selectedNeighborhoods.insert(hood)
                }
                expandedNeighborhoodGroup = nil
            }
        } label: {
            Text(hood)
                .font(.subheadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isSelected
                            ? AnyShapeStyle(LinearGradient(
                                colors: [color.opacity(0.35), color.opacity(0.15)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                            : AnyShapeStyle(Color(.systemGray6)))
                )
                .foregroundStyle(color)
        }
    }

    private func fetchEvents() async {
        isLoading = true
        errorMessage = nil
        lastFetchedCount = nil

        var totalImported = 0

        // 1. Fetch from Canopy backend (schedule items, curated events)
        do {
            print("[Canopy] Fetching events for city: \(CityConfig.citySlug)")
            let apiEvents = try await CanopyAPIService.shared.fetchEvents()
            print("[Canopy] API returned \(apiEvents.count) events")
            let count = await CanopyAPIService.shared.importEvents(apiEvents, into: modelContext)
            totalImported += count
            print("[Canopy] Imported \(count) events from backend")
        } catch let error as CanopyAPIError where error == .notConfigured {
            print("[Canopy] API not configured, skipping backend fetch")
        } catch is CancellationError {
            isLoading = false
            return
        } catch {
            print("[Canopy] Backend fetch error: \(error)")
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
                print("[Canopy] Ticketmaster returned \(tmEvents.count) events")
                let count = await TicketmasterService.shared.importEvents(tmEvents, into: modelContext)
                totalImported += count
                print("[Canopy] Imported \(count) events from Ticketmaster")
            } catch is CancellationError {
                isLoading = false
                return
            } catch {
                if totalImported == 0 && !events.isEmpty {
                    // Don't show error if we already have cached events
                } else if totalImported == 0 {
                    errorMessage = error.localizedDescription
                }
            }
        }

        let cityCounts = Dictionary(grouping: events, by: { $0.city ?? "nil" }).mapValues(\.count)
        let hoodCounts = Dictionary(grouping: events, by: { $0.neighborhood }).mapValues(\.count)
        print("[Canopy] Total events in SwiftData: \(events.count), by city: \(cityCounts), filtered for \(CityConfig.citySlug): \(filteredEvents.count)")
        print("[Canopy] Neighborhoods: \(hoodCounts)")
        // Log a few coordinate samples
        for e in events.prefix(3) {
            let hood = e.latitude.flatMap { lat in e.longitude.flatMap { lng in NeighborhoodLookup.lookup(latitude: lat, longitude: lng) } }
            print("[Canopy] Event '\(e.name)' at (\(e.latitude ?? 0), \(e.longitude ?? 0)) → neighborhood: \(e.neighborhood), lookup: \(hood ?? "nil")")
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
                        HStack(spacing: 6) {
                            Text(event.name)
                                .font(.headline)
                                .lineLimit(2)
                            if event.isCityOfficial == true {
                                CityOfficialBadge()
                            }
                        }

                        Label(event.location, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        if event.isFree == true || event.isAccessible == true || event.permitId != nil {
                            HStack(spacing: 6) {
                                if event.isFree == true {
                                    metaPill("Free", systemImage: "tag.fill", tint: Color.leafDeep)
                                }
                                if event.isAccessible == true {
                                    metaPill("Accessible", systemImage: "figure.roll", tint: .blue)
                                }
                                if let permit = event.permitId, !permit.isEmpty {
                                    metaPill(permit, systemImage: "checkmark.seal.fill", tint: .gray)
                                }
                            }
                            .padding(.top, 2)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(event.startDate, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.leafDeep)

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
                            .foregroundStyle(Color.leafDeep)
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
        case .festival: return .leafDeep
        case .concert: return .purple
        case .fair: return .orange
        case .conference: return .blue
        case .expo: return .cyan
        case .community: return .pink
        }
    }

    private func metaPill(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint)
            .background(
                Capsule().fill(tint.opacity(0.12))
            )
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

struct CityOfficialBadge: View {
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "building.columns.fill")
                .font(.system(size: 9, weight: .bold))
            Text("Official")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [Color.leafDeep, Color.leafShadow],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
        .accessibilityLabel("Official city event")
    }
}

struct ScrollMetrics: Equatable {
    var offset: CGFloat
    var contentHeight: CGFloat
}

struct ScrollMetricsTracker: ViewModifier {
    let viewportHeight: CGFloat
    let onChange: (ScrollMetrics, CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: ScrollMetrics.self) { geo in
                ScrollMetrics(
                    offset: geo.contentOffset.y + geo.contentInsets.top,
                    contentHeight: geo.contentSize.height
                )
            } action: { _, new in
                onChange(new, viewportHeight)
            }
        } else {
            content
        }
    }
}

struct LeafScrollIndicator: View {
    let scrollOffset: CGFloat
    let contentHeight: CGFloat
    let viewportHeight: CGFloat

    var body: some View {
        GeometryReader { geo in
            let trackHeight = geo.size.height
            let visibleRatio = contentHeight > 0 ? min(1, viewportHeight / contentHeight) : 1
            let thumbHeight = max(36, trackHeight * visibleRatio)
            let maxScroll = max(1, contentHeight - viewportHeight)
            let progress = min(1, max(0, scrollOffset / maxScroll))
            let thumbY = (trackHeight - thumbHeight) * progress
            let needsIndicator = contentHeight > viewportHeight + 1

            if needsIndicator {
                ZStack(alignment: .top) {
                    Capsule()
                        .fill(Color.leafDeep.opacity(0.08))
                        .frame(width: 4)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.leafLight, Color.leafMid, Color.leafDeep],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 5, height: thumbHeight)
                        .shadow(color: Color.leafMid.opacity(0.5), radius: 2, x: 0, y: 0)
                        .offset(y: thumbY)
                        .animation(.easeOut(duration: 0.12), value: thumbY)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(width: 6)
        .frame(maxHeight: .infinity)
    }
}

extension Color {
    static let leafLight  = Color(red: 0.525, green: 0.937, blue: 0.675) // #86EFAC
    static let leafMid    = Color(red: 0.290, green: 0.871, blue: 0.502) // #4ADE80
    static let leafDark   = Color(red: 0.133, green: 0.773, blue: 0.369) // #22C55E
    static let leafDeep   = Color(red: 0.086, green: 0.639, blue: 0.290) // #16A34A
    static let leafShadow = Color(red: 0.082, green: 0.502, blue: 0.239) // #15803D
}

struct SixLeavesDivider: View {
    var body: some View { LeafImageDivider(imageName: "SixLeaves", height: 16) }
}

struct ThreeLeavesDivider: View {
    var body: some View { LeafImageDivider(imageName: "ThreeLeaves", height: 16) }
}

struct LeafImageDivider: View {
    let imageName: String
    let height: CGFloat

    var body: some View {
        HStack(spacing: 8) {
            line
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        LinearGradient(
            colors: [Color.leafDeep.opacity(0.0), Color.leafDeep.opacity(0.49), Color.leafDeep.opacity(0.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct TwoLeavesIconDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            line
            HStack(spacing: 4) {
                leaf.scaleEffect(x: -1, y: -1, anchor: .center)
                leaf.scaleEffect(x: 1, y: -1, anchor: .center)
            }
            line
        }
        .accessibilityHidden(true)
    }

    private var leaf: some View {
        Image(systemName: "leaf.fill")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.leafDark, Color.leafLight],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .rotationEffect(.degrees(145))
    }

    private var line: some View {
        LinearGradient(
            colors: [Color.leafDeep.opacity(0.0), Color.leafDeep.opacity(0.49), Color.leafDeep.opacity(0.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

struct LeafyDivider: View {
    var body: some View {
        HStack(spacing: 8) {
            line
            Image(systemName: "leaf.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.leafDark, .leafLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .rotationEffect(.degrees(-35))
            line
        }
        .accessibilityHidden(true)
    }

    private var line: some View {
        LinearGradient(
            colors: [Color.leafDeep.opacity(0.0), Color.leafDeep.opacity(0.49), Color.leafDeep.opacity(0.0)],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1)
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
