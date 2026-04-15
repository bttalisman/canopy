import SwiftUI
import GoogleMaps

struct GoogleMapView: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let span: Double
    var markers: [(lat: Double, lng: Double, title: String, color: UIColor)]
    var isSatellite: Bool = false
    var boundaryCoords: [CLLocationCoordinate2D] = []
    var recenterTrigger: Int = 0
    @AppStorage("appearanceMode") private var appearanceMode = 0

    func makeUIView(context: Context) -> GMSMapView {
        let camera = GMSCameraPosition(
            latitude: latitude,
            longitude: longitude,
            zoom: zoomFromSpan(span)
        )
        let options = GMSMapViewOptions()
        options.camera = camera
        let mapView = GMSMapView(options: options)

        switch appearanceMode {
        case 1: mapView.overrideUserInterfaceStyle = .light
        case 2: mapView.overrideUserInterfaceStyle = .dark
        default: mapView.overrideUserInterfaceStyle = .unspecified
        }

        mapView.mapType = isSatellite ? .hybrid : .normal
        mapView.settings.compassButton = true
        mapView.settings.myLocationButton = true
        mapView.isMyLocationEnabled = true

        addMarkers(to: mapView)
        if !boundaryCoords.isEmpty { addBoundary(to: mapView) }
        return mapView
    }

    func updateUIView(_ mapView: GMSMapView, context: Context) {
        switch appearanceMode {
        case 1: mapView.overrideUserInterfaceStyle = .light
        case 2: mapView.overrideUserInterfaceStyle = .dark
        default: mapView.overrideUserInterfaceStyle = .unspecified
        }
        mapView.mapType = isSatellite ? .hybrid : .normal
        mapView.clear()
        addMarkers(to: mapView)
        if !boundaryCoords.isEmpty { addBoundary(to: mapView) }

        // Recenter when trigger changes
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            let camera = GMSCameraPosition(
                latitude: latitude,
                longitude: longitude,
                zoom: zoomFromSpan(span)
            )
            mapView.animate(to: camera)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastRecenterTrigger: Int = 0
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
        let pinSize: CGFloat = 36
        let totalWidth: CGFloat = 140
        let labelHeight: CGFloat = 18

        let container = UIView()
        container.frame = CGRect(x: 0, y: 0, width: totalWidth, height: pinSize + labelHeight + 2)

        // Draw pin shape
        let pinView = UIView(frame: CGRect(x: (totalWidth - pinSize) / 2, y: 0, width: pinSize, height: pinSize))

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: pinSize, height: pinSize))
        let pinImage = renderer.image { ctx in
            let rect = CGRect(x: 2, y: 2, width: pinSize - 4, height: pinSize - 4)
            let path = UIBezierPath()
            let cx = rect.midX
            let top = rect.minY
            let radius = rect.width / 2.4
            let tipY = rect.maxY

            // Teardrop: circle at top, point at bottom
            path.addArc(withCenter: CGPoint(x: cx, y: top + radius), radius: radius, startAngle: .pi * 0.85, endAngle: .pi * 0.15, clockwise: true)
            path.addLine(to: CGPoint(x: cx, y: tipY))
            path.close()

            // Shadow
            ctx.cgContext.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor.black.withAlphaComponent(0.5).cgColor)
            color.setFill()
            path.fill()

            // White border
            ctx.cgContext.setShadow(offset: .zero, blur: 0)
            UIColor.white.setStroke()
            path.lineWidth = 1.5
            path.stroke()

            // Icon
            let iconConfig = UIImage.SymbolConfiguration(pointSize: pinSize * 0.3, weight: .bold)
            if let icon = UIImage(systemName: symbolForTitle(title), withConfiguration: iconConfig) {
                let tinted = icon.withTintColor(.white, renderingMode: .alwaysOriginal)
                let iconSize = tinted.size
                let iconRect = CGRect(
                    x: cx - iconSize.width / 2,
                    y: top + radius - iconSize.height / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                tinted.draw(in: iconRect)
            }
        }

        let imageView = UIImageView(image: pinImage)
        imageView.frame = pinView.frame
        container.addSubview(imageView)

        // Label below pin
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = color.withAlphaComponent(0.8)
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail

        let textSize = label.sizeThatFits(CGSize(width: totalWidth - 8, height: 20))
        let labelWidth = min(textSize.width + 10, totalWidth)
        label.frame = CGRect(
            x: (totalWidth - labelWidth) / 2,
            y: pinSize + 2,
            width: labelWidth,
            height: labelHeight
        )
        container.addSubview(label)

        return container
    }

    private func symbolForTitle(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("restroom") || t.contains("bathroom") { return "figure.stand" }
        if t.contains("food") || t.contains("restaurant") || t.contains("eat") { return "fork.knife" }
        if t.contains("stage") || t.contains("music") || t.contains("performance") { return "music.mic" }
        if t.contains("first aid") || t.contains("medical") { return "cross.fill" }
        if t.contains("exit") || t.contains("entrance") { return "arrow.right.circle" }
        if t.contains("wifi") { return "wifi" }
        if t.contains("accessible") || t.contains("ada") { return "figure.roll" }
        if t.contains("atm") || t.contains("cash") { return "dollarsign.circle" }
        if t.contains("parking") { return "p.circle.fill" }
        if t.contains("info") || t.contains("information") { return "info.circle" }
        if t.contains("shop") || t.contains("merch") || t.contains("gift") { return "bag.fill" }
        if t.contains("bus") || t.contains("transit") { return "bus.fill" }
        return "mappin"
    }

    private func addBoundary(to mapView: GMSMapView) {
        let path = GMSMutablePath()
        for coord in boundaryCoords {
            path.add(coord)
        }

        let polygon = GMSPolygon(path: path)
        polygon.fillColor = UIColor.systemGreen.withAlphaComponent(0.08)
        polygon.strokeColor = UIColor.systemGreen.withAlphaComponent(0.6)
        polygon.strokeWidth = 2
        polygon.map = mapView
    }

    private func zoomFromSpan(_ span: Double) -> Float {
        let zoom = log2(360.0 / max(span, 0.001)) - 1
        return Float(min(max(zoom, 1), 20))
    }
}
