import SwiftUI
import MapKit
import GoogleMaps

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
    var allEvents: [Event] = []
    @Binding var selectedEvent: Event?
    var showDateSlider: Bool = true
    var selectedNeighborhood: String? = nil
    @State private var selectedCluster: VenueCluster?
    @State private var dateRange: ClosedRange<Date> = {
        let now = Calendar.current.startOfDay(for: Date())
        let sixMonths = Calendar.current.date(byAdding: .month, value: 6, to: now) ?? now.addingTimeInterval(180 * 24 * 3600)
        return now...sixMonths
    }()


    private var dateMin: Date {
        let source = allEvents.isEmpty ? events : allEvents
        return source.map(\.startDate).min() ?? Date()
    }

    private var dateMax: Date {
        let source = allEvents.isEmpty ? events : allEvents
        let latest = source.map(\.endDate).max() ?? Date()
        return max(latest, Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
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
            DiscoverGoogleMap(
                clusters: venueClusters,
                selectedClusterId: selectedCluster?.id,
                onClusterTap: { cluster in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedCluster = cluster
                        selectedEvent = nil
                    }
                }
            )

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
                                            CachedAsyncImage(url: url) { image in
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(width: 44, height: 44)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                            } placeholder: {
                                                categoryThumb(event.category)
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
        .onChange(of: selectedNeighborhood) { _, _ in
            panToFilteredEvents()
        }
    }

    private func panToFilteredEvents() {
        selectedCluster = nil
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

// MARK: - Google Maps wrapper for Discover view

struct DiscoverGoogleMap: UIViewRepresentable {
    let clusters: [VenueCluster]
    var selectedClusterId: UUID?
    var onClusterTap: (VenueCluster) -> Void
    @AppStorage("appearanceMode") private var appearanceMode = 0

    func makeCoordinator() -> Coordinator {
        Coordinator(onClusterTap: onClusterTap)
    }

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(latitude: 47.6200, longitude: -122.3350, zoom: 11)
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)
        mapView.delegate = context.coordinator
        applyAppearance(mapView)
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        applyAppearance(mapView)
        context.coordinator.clusters = clusters
        context.coordinator.onClusterTap = onClusterTap
        mapView.clear()

        for cluster in clusters {
            let marker = GMSMarker()
            marker.position = cluster.coordinate
            marker.userData = cluster.id.uuidString

            let isSelected = selectedClusterId == cluster.id
            let color = isSelected ? UIColor.systemGreen : uiCategoryColor(cluster.primaryCategory)

            let pinView = makeClusterPin(
                icon: cluster.primaryCategory.systemImage,
                count: cluster.events.count,
                color: color
            )
            marker.iconView = pinView
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.map = mapView
        }
    }

    private func applyAppearance(_ mapView: GMSMapView) {
        switch appearanceMode {
        case 1: mapView.overrideUserInterfaceStyle = .light
        case 2: mapView.overrideUserInterfaceStyle = .dark
        default: mapView.overrideUserInterfaceStyle = .unspecified
        }
    }

    private func makeClusterPin(icon: String, count: Int, color: UIColor) -> UIView {
        let size: CGFloat = 36
        let container = UIView(frame: CGRect(x: 0, y: 0, width: size + 16, height: size + 8))

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let pinImage = renderer.image { ctx in
            let rect = CGRect(x: 2, y: 2, width: size - 4, height: size - 4)
            let path = UIBezierPath()
            let cx = rect.midX
            let radius = rect.width / 2.4
            let tipY = rect.maxY

            path.addArc(withCenter: CGPoint(x: cx, y: rect.minY + radius), radius: radius, startAngle: .pi * 0.85, endAngle: .pi * 0.15, clockwise: true)
            path.addLine(to: CGPoint(x: cx, y: tipY))
            path.close()

            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            color.setFill()
            path.fill()

            ctx.cgContext.setShadow(offset: .zero, blur: 0)
            UIColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()

            let iconConfig = UIImage.SymbolConfiguration(pointSize: size * 0.3, weight: .bold)
            if let iconImg = UIImage(systemName: icon, withConfiguration: iconConfig) {
                let tinted = iconImg.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize = tinted.size
                tinted.draw(in: CGRect(
                    x: cx - iconSize.width / 2,
                    y: rect.minY + radius - iconSize.height / 2,
                    width: iconSize.width,
                    height: iconSize.height
                ))
            }
        }

        let imageView = UIImageView(image: pinImage)
        imageView.frame = CGRect(x: 8, y: 0, width: size, height: size)
        container.addSubview(imageView)

        if count > 1 {
            let badge = UILabel()
            badge.text = "\(count)"
            badge.font = .systemFont(ofSize: 9, weight: .bold)
            badge.textColor = .white
            badge.textAlignment = .center
            badge.backgroundColor = .systemRed
            badge.layer.cornerRadius = 8
            badge.layer.masksToBounds = true
            badge.frame = CGRect(x: size - 2, y: 0, width: 16, height: 16)
            container.addSubview(badge)
        }

        return container
    }

    private func uiCategoryColor(_ category: EventCategory) -> UIColor {
        switch category {
        case .festival: return .systemGreen
        case .concert: return .systemPurple
        case .fair: return .systemOrange
        case .conference: return .systemBlue
        case .expo: return .systemCyan
        case .community: return .systemPink
        }
    }

    class Coordinator: NSObject, GMSMapViewDelegate {
        var clusters: [VenueCluster] = []
        var onClusterTap: (VenueCluster) -> Void

        init(onClusterTap: @escaping (VenueCluster) -> Void) {
            self.onClusterTap = onClusterTap
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let idString = marker.userData as? String,
                  let cluster = clusters.first(where: { $0.id.uuidString == idString }) else {
                return false
            }
            onClusterTap(cluster)
            return true
        }
    }
}
