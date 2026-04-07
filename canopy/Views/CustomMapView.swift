import SwiftUI

struct CustomMapView: View {
    let url: URL
    let pins: [MapPin]
    @Binding var selectedPin: MapPin?
    var pinSizePercent: CGFloat = 3 // percentage of map width

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var cachedImage: UIImage?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6)

                if let uiImage = cachedImage {
                    let image = Image(uiImage: uiImage)

                    image
                        .resizable()
                        .scaledToFit()
                        .overlay(pinOverlay)
                        .drawingGroup()
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = min(lastScale * value, 10.0)
                                }
                                .onEnded { _ in
                                    lastScale = min(max(scale, 1.0), 10.0)
                                    scale = lastScale
                                    clampOffset(containerWidth: geo.size.width)
                                }
                        )
                        .gesture(
                            DragGesture(minimumDistance: scale > 1.05 ? 5 : 10000)
                                .onChanged { value in
                                    let raw = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    guard let img = cachedImage else { offset = raw; return }
                                    let ar = img.size.height / img.size.width
                                    let w = geo.size.width
                                    let maxX = max((scale * w - w) / 2, 0)
                                    let maxY = max((scale * w * ar - 400) / 2, 0)
                                    offset = CGSize(
                                        width: min(max(raw.width, -maxX), maxX),
                                        height: min(max(raw.height, -maxY), maxY)
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if scale > 1.5 {
                                    scale = 1.0
                                    lastScale = 1.0
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    scale = 3.0
                                    lastScale = 3.0
                                }
                            }
                        }
                } else {
                    ProgressView()
                }
            }
        }
        .frame(height: 400)
        .contentShape(Rectangle())
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .task {
            guard cachedImage == nil else { return }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                cachedImage = UIImage(data: data)
            } catch {
            }
        }
    }

    private func clampOffset(containerWidth: CGFloat) {
        // The image is scaledToFit inside the container
        // We need the actual rendered image size to compute bounds
        guard let img = cachedImage else { return }
        let aspectRatio = img.size.height / img.size.width
        let imageWidth = containerWidth
        let imageHeight = containerWidth * aspectRatio

        let maxX = max((scale * imageWidth - containerWidth) / 2, 0)
        let maxY = max((scale * imageHeight - 400) / 2, 0) // 400 = frame height


        offset.width = min(max(offset.width, -maxX), maxX)
        offset.height = min(max(offset.height, -maxY), maxY)
        lastOffset = offset
    }

    private var pinOverlay: some View {
        GeometryReader { imgGeo in
            let computedPinSize = imgGeo.size.width * pinSizePercent / 100
            ForEach(pins) { pin in
                pinMarker(pin, size: computedPinSize)
                    .position(
                        x: pin.x * imgGeo.size.width,
                        y: pin.y * imgGeo.size.height
                    )
                    .allowsHitTesting(false)
                    .accessibilityLabel(pin.label)
            }
        }
    }

    private func pinMarker(_ pin: MapPin, size: CGFloat) -> some View {
        VStack(spacing: 1) {
            Image(systemName: pin.pinType.systemImage)
                .font(.system(size: max(size * 0.45, 4)))
                .foregroundStyle(.white)
                .frame(width: max(size, 4), height: max(size, 4))
                .background(pinColor(pin.pinType))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.4), radius: 2)

            if selectedPin?.id == pin.id {
                Text(pin.label)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(pinColor(pin.pinType).opacity(0.9))
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
    }

    private func pinColor(_ type: MapPinType) -> Color {
        switch type {
        case .restroom: return .blue
        case .food: return .orange
        case .stage: return .purple
        case .firstAid: return .red
        case .exit: return .green
        case .wifi: return .cyan
        case .accessible: return .indigo
        case .atm: return .yellow
        case .parking: return .blue
        case .info: return .teal
        case .giftShop: return .pink
        case .bus: return .green
        case .custom: return .gray
        }
    }
}
