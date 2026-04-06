import SwiftUI
import MapKit

struct VenueCluster: Identifiable {
    let id = UUID()
    let location: String
    let coordinate: CLLocationCoordinate2D
    let events: [Event]

    var primaryCategory: EventCategory {
        // Most common category in the cluster
        let counts = Dictionary(grouping: events, by: \.category).mapValues(\.count)
        return counts.max(by: { $0.value < $1.value })?.key ?? .festival
    }
}

struct DiscoverMapView: View {
    let events: [Event]
    @Binding var selectedEvent: Event?
    var showDateSlider: Bool = true
    @State private var selectedCluster: VenueCluster?
    @State private var dateRange: ClosedRange<Date> = {
        let now = Calendar.current.startOfDay(for: Date())
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: now)!
        return now...sixMonths
    }()

    @State private var position = MapCameraPosition.region(MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 47.6200, longitude: -122.3350),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    ))

    private var dateMin: Date {
        events.map(\.startDate).min() ?? Date()
    }

    private var dateMax: Date {
        let latest = events.map(\.endDate).max() ?? Date()
        return max(latest, Calendar.current.date(byAdding: .month, value: 1, to: Date())!)
    }

    private var dateFilteredEvents: [Event] {
        guard showDateSlider else { return events }
        return events.filter { event in
            event.startDate <= dateRange.upperBound && event.endDate >= dateRange.lowerBound
        }
    }

    var venueClusters: [VenueCluster] {
        let eventsWithCoords = dateFilteredEvents.filter { $0.latitude != nil && $0.longitude != nil }

        // Group by rounded coordinates (~100m radius)
        let grouped = Dictionary(grouping: eventsWithCoords) { event -> String in
            let lat = ((event.latitude ?? 0) * 1000).rounded() / 1000
            let lng = ((event.longitude ?? 0) * 1000).rounded() / 1000
            return "\(lat),\(lng)"
        }

        return grouped.map { _, events in
            let first = events[0]
            return VenueCluster(
                location: first.location,
                coordinate: CLLocationCoordinate2D(
                    latitude: first.latitude ?? 0,
                    longitude: first.longitude ?? 0
                ),
                events: events.sorted { $0.startDate < $1.startDate }
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Date range slider (only in "Any Time" mode)
            if showDateSlider {
            VStack(spacing: 4) {
                HStack {
                    Text(dateRange.lowerBound, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Spacer()
                    Text("\(dateFilteredEvents.count) event\(dateFilteredEvents.count == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(dateRange.upperBound, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                }

                DateRangeSlider(
                    range: $dateRange,
                    bounds: dateMin...dateMax
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            }

            ZStack(alignment: .bottom) {
            Map(position: $position) {
                ForEach(venueClusters) { cluster in
                    Annotation(cluster.location, coordinate: cluster.coordinate) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCluster = cluster
                                selectedEvent = nil
                            }
                        } label: {
                            ZStack {
                                Image(systemName: cluster.primaryCategory.systemImage)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        selectedCluster?.id == cluster.id
                                            ? Color.green
                                            : categoryColor(cluster.primaryCategory)
                                    )
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 3, y: 2)

                                if cluster.events.count > 1 {
                                    Text("\(cluster.events.count)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(3)
                                        .background(Color.red)
                                        .clipShape(Circle())
                                        .offset(x: 12, y: -12)
                                }
                            }
                        }
                        .accessibilityLabel("\(cluster.events.count) event\(cluster.events.count == 1 ? "" : "s") at \(cluster.location)")
                    }
                }
            }

            // Selected venue card overlay
            if let cluster = selectedCluster {
                VStack(spacing: 0) {
                    // Venue header
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundStyle(.green)
                        Text(cluster.location)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(cluster.events.count) event\(cluster.events.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            withAnimation { selectedCluster = nil }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    // Event list
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            ForEach(cluster.events) { event in
                                NavigationLink(value: event) {
                                    HStack(spacing: 10) {
                                        // Thumbnail
                                        if let imageURL = event.imageURL, let url = URL(string: imageURL) {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 44, height: 44)
                                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                                default:
                                                    categoryThumb(event.category)
                                                }
                                            }
                                        } else {
                                            categoryThumb(event.category)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(event.name)
                                                .font(.caption)
                                                .fontWeight(.semibold)
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)

                                            HStack(spacing: 4) {
                                                Text(event.startDate, format: .dateTime.month(.abbreviated).day())
                                                    .font(.caption2)
                                                    .foregroundStyle(.green)
                                                Text(event.category.rawValue)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 10)
                    }
                    .frame(maxHeight: min(CGFloat(cluster.events.count) * 60, 180))
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal)
                .padding(.bottom, 90)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        } // close outer VStack
    }

    private func categoryThumb(_ category: EventCategory) -> some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(categoryColor(category).opacity(0.2))
            .frame(width: 44, height: 44)
            .overlay(
                Image(systemName: category.systemImage)
                    .font(.caption)
                    .foregroundStyle(categoryColor(category))
            )
    }

    private func categoryColor(_ category: EventCategory) -> Color {
        switch category {
        case .festival: return .green
        case .concert: return .purple
        case .fair: return .orange
        case .conference: return .blue
        case .expo: return .cyan
        case .community: return .pink
        }
    }
}
