import SwiftUI
import MapKit
import CoreLocation

struct TransitDirectionsView: View {
    let venueName: String
    let venueLatitude: Double
    let venueLongitude: Double

    @ObservedObject private var locationManager = LocationManager.shared
    @State private var routes: [TransitRoute] = []
    @State private var realTimeArrivals: [RealTimeArrival] = []
    @State private var isLoadingRoutes = true
    @State private var isLoadingArrivals = true
    @State private var selectedRouteIndex = 0
    @State private var routeError: String?
    @State private var refreshTimer: Timer?

    private var destination: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: venueLatitude, longitude: venueLongitude)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Transit Directions", systemImage: "bus.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            // Apple Maps transit button (always show)
            Button {
                openInAppleMaps()
            } label: {
                Label("Get Transit Directions", systemImage: "map.fill")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .accessibilityLabel("Open transit directions to \(venueName) in Apple Maps")

            if isLoadingRoutes {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Finding routes...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !routes.isEmpty {
                // Route selector (if multiple)
                if routes.count > 1 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                                Button {
                                    withAnimation { selectedRouteIndex = index }
                                } label: {
                                    VStack(spacing: 2) {
                                        Text("\(route.totalMinutes) min")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                        Text(route.summary)
                                            .font(.caption2)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(selectedRouteIndex == index ? Color.green : Color(.systemGray6))
                                    .foregroundStyle(selectedRouteIndex == index ? .white : .primary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .accessibilityLabel("Route option: \(route.totalMinutes) minutes via \(route.summary)")
                                .accessibilityAddTraits(selectedRouteIndex == index ? .isSelected : [])
                            }
                        }
                    }
                }

                // Step-by-step directions
                let route = routes[min(selectedRouteIndex, routes.count - 1)]

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(route.steps.enumerated()), id: \.element.id) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            // Icon column with connecting line
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle()
                                        .fill(stepColor(step.transportType))
                                        .frame(width: 28, height: 28)
                                    Image(systemName: step.transportType.sfSymbol)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white)
                                }

                                if index < route.steps.count - 1 {
                                    Rectangle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 2)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 28)

                            // Instruction
                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.instruction)
                                    .font(.subheadline)

                                HStack(spacing: 8) {
                                    if let lineName = step.lineName {
                                        Text(lineName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.green)
                                    }
                                    if step.durationMinutes > 0 {
                                        Text("\(step.durationMinutes) min")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let distance = step.distance, step.transportType == .walk {
                                        Text(formatDistance(distance))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.bottom, 12)
                        }
                    }
                }

                // Total time
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Total: \(route.totalMinutes) min")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }

            // Real-time arrivals (shown independently of MKDirections routes)
            if !realTimeArrivals.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Nearby Departures")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if isLoadingArrivals {
                                ProgressView()
                                    .controlSize(.mini)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                        }

                        ForEach(realTimeArrivals.prefix(6)) { arrival in
                            HStack(spacing: 8) {
                                Text(arrival.routeName)
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))

                                VStack(alignment: .leading, spacing: 0) {
                                    Text(arrival.headsign)
                                        .font(.caption)
                                        .lineLimit(1)
                                    Text(arrival.stopName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Text(arrival.minutesUntilArrival == 0 ? "Now" : "\(arrival.minutesUntilArrival) min")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(arrival.minutesUntilArrival <= 3 ? .orange : .primary)

                                if arrival.isRealTime {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 6, height: 6)
                                        .accessibilityLabel("Real-time data")
                                }
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("\(arrival.routeName) toward \(arrival.headsign), \(arrival.minutesUntilArrival == 0 ? "arriving now" : "in \(arrival.minutesUntilArrival) minutes")\(arrival.isRealTime ? ", real-time" : "")")
                        }
                    }
                }


            if isLoadingArrivals && realTimeArrivals.isEmpty && routes.isEmpty {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking nearby departures...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            await loadRoutes()
            await loadArrivals()
        }
        .onAppear { startAutoRefresh() }
        .onDisappear { stopAutoRefresh() }
    }

    // MARK: - Subviews

    private var appleMapsButton: some View {
        Button {
            openInAppleMaps()
        } label: {
            Label("Apple Maps", systemImage: "map.fill")
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel("Open transit directions in Apple Maps")
    }

    // MARK: - Data Loading

    private func loadRoutes() async {
        guard let userLoc = locationManager.userLocation else {
            routeError = "Location not available"
            isLoadingRoutes = false
            return
        }

        do {
            let result = try await TransitService.shared.fetchTransitRoutes(
                from: userLoc.coordinate, to: destination
            )
            routes = result
            if result.isEmpty {
                routeError = "No transit routes available"
            }
        } catch {
            routeError = error.localizedDescription
        }
        isLoadingRoutes = false
    }

    private func loadArrivals() async {
        guard let userLoc = locationManager.userLocation else {
            isLoadingArrivals = false
            return
        }

        let arrivals = await TransitService.shared.fetchRealTimeArrivals(
            latitude: userLoc.coordinate.latitude,
            longitude: userLoc.coordinate.longitude
        )
        realTimeArrivals = arrivals
        isLoadingArrivals = false
    }

    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { await loadArrivals() }
        }
    }

    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Helpers

    private func openInAppleMaps() {
        let dest = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        dest.name = venueName
        dest.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeTransit])
    }

    private func stepColor(_ type: TransitStepType) -> Color {
        switch type {
        case .walk: return .gray
        case .bus: return .green
        case .train: return .blue
        case .ferry: return .cyan
        case .other: return .gray
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return "\(Int(meters))m"
        }
        return String(format: "%.1f km", meters / 1000)
    }
}
