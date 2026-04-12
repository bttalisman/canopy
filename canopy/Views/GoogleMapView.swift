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

        mapView.overrideUserInterfaceStyle = .dark
        if let styleURL = Bundle.main.url(forResource: "google-map-style", withExtension: "json"),
           let style = try? GMSMapStyle(contentsOfFileURL: styleURL) {
            mapView.mapStyle = style
        }

        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true

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
            marker.iconView = makeLabeledPin(title: m.title, color: m.color)
            marker.groundAnchor = CGPoint(x: 0.5, y: 1.0)
            marker.map = mapView
        }
    }

    private func makeLabeledPin(title: String, color: UIColor) -> UIView {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 2

        // Label
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color.withAlphaComponent(0.85)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        let padding: CGFloat = 6
        let maxWidth: CGFloat = 120
        let textSize = label.sizeThatFits(CGSize(width: maxWidth, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: 0, y: 0, width: min(textSize.width + padding * 2, maxWidth), height: textSize.height + 4)

        // Pin dot
        let dot = UIView()
        dot.backgroundColor = color
        dot.layer.cornerRadius = 6
        dot.layer.borderWidth = 2
        dot.layer.borderColor = UIColor.white.cgColor
        dot.frame = CGRect(x: 0, y: 0, width: 12, height: 12)
        dot.widthAnchor.constraint(equalToConstant: 12).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 12).isActive = true

        container.addArrangedSubview(label)
        container.addArrangedSubview(dot)

        let totalHeight = label.frame.height + 2 + 12
        let totalWidth = max(label.frame.width, 12)
        container.frame = CGRect(x: 0, y: 0, width: totalWidth, height: totalHeight)

        return container
    }

    private func zoomFromSpan(_ span: Double) -> Float {
        let zoom = log2(360.0 / max(span, 0.001)) - 1
        return Float(min(max(zoom, 1), 20))
    }
}
