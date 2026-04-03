import SwiftUI
import CoreLocation

struct RideShareView: View {
    let venueName: String
    let venueLatitude: Double
    let venueLongitude: Double

    @ObservedObject private var locationManager = LocationManager.shared

    private var distanceText: String? {
        guard let miles = locationManager.distanceTo(latitude: venueLatitude, longitude: venueLongitude) else {
            return nil
        }
        return String(format: "%.1f miles to %@", miles, venueName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Get a Ride", systemImage: "car.fill")
                .font(.subheadline)
                .fontWeight(.semibold)

            if let distance = distanceText {
                Text(distance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                // Uber button
                Button {
                    openRideApp(
                        scheme: "uber://?action=setPickup&pickup=my_location&dropoff[latitude]=\(venueLatitude)&dropoff[longitude]=\(venueLongitude)&dropoff[nickname]=\(venueName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? venueName)",
                        appStoreURL: "https://apps.apple.com/app/uber/id368677368"
                    )
                } label: {
                    HStack {
                        Text("Uber")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Request Uber ride to \(venueName)")
                .accessibilityHint("Opens Uber app or App Store")

                // Lyft button
                Button {
                    openRideApp(
                        scheme: "lyft://ridetype?id=lyft&destination[latitude]=\(venueLatitude)&destination[longitude]=\(venueLongitude)",
                        appStoreURL: "https://apps.apple.com/app/lyft/id529379082"
                    )
                } label: {
                    HStack {
                        Text("Lyft")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.92, green: 0.0, blue: 0.55))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .accessibilityLabel("Request Lyft ride to \(venueName)")
                .accessibilityHint("Opens Lyft app or App Store")
            }
        }
    }

    private func openRideApp(scheme: String, appStoreURL: String) {
        guard let schemeURL = URL(string: scheme) else { return }

        if UIApplication.shared.canOpenURL(schemeURL) {
            UIApplication.shared.open(schemeURL)
        } else if let storeURL = URL(string: appStoreURL) {
            UIApplication.shared.open(storeURL)
        }
    }
}
