import SwiftUI
import SwiftData

struct DiscoverView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Event.startDate) private var events: [Event]
    @AppStorage("ticketmasterAPIKey") private var apiKey = ""
    @State private var searchText = ""
    @State private var selectedCategory: EventCategory?
    @State private var selectedTimeFilter: TimeFilter = .all
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var lastFetchedCount: Int?
    @State private var showingAPIKeyAlert = false

    enum TimeFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case thisWeek = "This Week"
        case thisWeekend = "This Weekend"
        case thisMonth = "This Month"

        var id: String { rawValue }
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
            let daysUntilSaturday = (7 - weekday) % 7
            let saturday = calendar.date(byAdding: .day, value: daysUntilSaturday == 0 && weekday != 7 ? 6 : daysUntilSaturday, to: now)!
            let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
            let endOfSunday = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: sunday)!
            let startOfSaturday = calendar.startOfDay(for: saturday)
            result = result.filter { $0.startDate <= endOfSunday && $0.endDate >= startOfSaturday }
        case .thisMonth:
            let endOfMonth = calendar.date(byAdding: .month, value: 1, to: now)!
            result = result.filter { $0.startDate <= endOfMonth && $0.endDate >= now }
        }

        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Time filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(TimeFilter.allCases) { filter in
                                Button {
                                    withAnimation {
                                        selectedTimeFilter = filter
                                    }
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
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Category filter pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
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

                    // Status messages
                    if isLoading {
                        ProgressView("Fetching Seattle events...")
                            .padding(.top, 40)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                                .multilineTextAlignment(.center)

                            if apiKey.isEmpty {
                                Button("Add API Key") {
                                    showingAPIKeyAlert = true
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                            } else {
                                Button("Retry") {
                                    Task { await fetchEvents() }
                                }
                                .buttonStyle(.bordered)
                            }
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
                            description: Text(apiKey.isEmpty
                                ? "Add your Ticketmaster API key in Settings to discover events."
                                : "Try adjusting your filters or pull to refresh.")
                        )
                        .padding(.top, 60)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEvents) { event in
                                NavigationLink(value: event) {
                                    EventCard(event: event)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Discover Seattle")
            .searchable(text: $searchText, prompt: "Search events, venues...")
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event)
            }
            .refreshable {
                await fetchEvents()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await fetchEvents() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || apiKey.isEmpty)
                }
            }
            .alert("Ticketmaster API Key", isPresented: $showingAPIKeyAlert) {
                TextField("API Key", text: $apiKey)
                Button("Save", role: .cancel) {}
            } message: {
                Text("Get a free key at developer.ticketmaster.com")
            }
            .task {
                if events.isEmpty && !apiKey.isEmpty {
                    await fetchEvents()
                }
            }
        }
    }

    private func fetchEvents() async {
        guard !apiKey.isEmpty else {
            errorMessage = "No API key. Add your Ticketmaster API key in Settings."
            return
        }

        isLoading = true
        errorMessage = nil
        lastFetchedCount = nil

        do {
            // Format start time as ISO8601 (now)
            let formatter = ISO8601DateFormatter()
            let startDT = formatter.string(from: Date())

            let response = try await TicketmasterService.shared.searchEvents(
                apiKey: apiKey,
                startDateTime: startDT
            )

            let tmEvents = response.embedded?.events ?? []
            let count = await TicketmasterService.shared.importEvents(tmEvents, into: modelContext)
            lastFetchedCount = count

            // Clear status after a few seconds
            try? await Task.sleep(for: .seconds(3))
            lastFetchedCount = nil
        } catch {
            errorMessage = error.localizedDescription
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
                            .aspectRatio(16/9, contentMode: .fill)
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
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    private var fallbackHeader: some View {
        HStack {
            Spacer()
            Image(systemName: event.logoSystemImage)
                .font(.system(size: 32))
                .foregroundStyle(.green.opacity(0.5))
            Spacer()
        }
        .frame(height: 100)
        .background(Color.green.opacity(0.08))
    }
}

#Preview {
    DiscoverView()
        .modelContainer(for: [
            Event.self, Stage.self, ScheduleItem.self,
            MapPin.self, UserSavedItem.self
        ], inMemory: true)
}
