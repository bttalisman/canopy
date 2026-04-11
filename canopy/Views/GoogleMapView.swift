import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let span: Double
    var markers: [(lat: Double, lng: Double, title: String, color: UIColor)]

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: latitude,
            longitude: longitude,
            zoom: zoomFromSpan(span)
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)

        // Dark style matching the app theme
        mapView.overrideUserInterfaceStyle = .dark
        if let styleURL = Bundle.main.url(forResource: "google-map-style", withExtension: "json"),
           let style = try? GMSMapStyle(contentsOfFileURL: styleURL) {
            mapView.mapStyle = style
        }

        addMarkers(to: mapView)
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.clear()
        addMarkers(to: mapView)
    }

    private func addMarkers(to mapView: GMSMapView) {
        for m in markers {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: m.lat, longitude: m.lng)
            marker.title = m.title
            marker.icon = GMSMarker.markerImage(with: m.color)
            marker.map = mapView
        }
    }

    private func zoomFromSpan(_ span: Double) -> Float {
        // Approximate conversion from MKCoordinateSpan delta to Google Maps zoom
        let zoom = log2(360.0 / max(span, 0.001)) - 1
        return Float(min(max(zoom, 1), 20))
    }
}
