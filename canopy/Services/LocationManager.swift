import CoreLocation
import Combine

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    private let manager = CLLocationManager()

    // Toggle this to simulate being in Capitol Hill for testing
    // Set to false for real location
    static let useDebugLocation = false
    private static let debugLocation = CLLocation(latitude: 47.6150, longitude: -122.3200) // Capitol Hill

    @Published var userLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        if Self.useDebugLocation {
            userLocation = Self.debugLocation
        }
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !Self.useDebugLocation else { return }
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !Self.useDebugLocation else { return }
        userLocation = locations.last
    }

    func distanceTo(latitude: Double, longitude: Double) -> Double? {
        guard let userLoc = userLocation else { return nil }
        let destination = CLLocation(latitude: latitude, longitude: longitude)
        let meters = userLoc.distance(from: destination)
        return meters / 1609.34 // convert to miles
    }
}
