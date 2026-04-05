import SwiftUI

struct CustomMapView: View {
    let url: URL
    let pins: [MapPin]
    @Binding var selectedPin: MapPin?

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var imageSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(.systemGray6)

                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        let rendered = image.resizable().scaledToFit()

                        ZStack(alignment: .topLeading) {
                            rendered
                                .background(
                                    GeometryReader { imgGeo in
                                        Color.clear.onAppear {
                                            imageSize = imgGeo.size
                                        }
                                        .onChange(of: imgGeo.size) { _, newSize in
                                            imageSize = newSize
                                        }
                                    }
                                )

                            if imageSize.width > 0 && imageSize.height > 0 {
                                ForEach(pins) { pin in
                                    Button {
                                        selectedPin = pin
                                    } label: {
                                        pinMarker(pin)
                                    }
                                    .position(
                                        x: pin.x * imageSize.width,
                                        y: pin.y * imageSize.height
                                    )
                                    .accessibilityLabel(pin.label)
                                }
                            }
                        }
                        .frame(width: geo.size.width, height: geo.size.width * (imageSize.height / max(imageSize.width, 1)))
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = max(scale, 1.0)
                                    scale = lastScale
                                }
                        )
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    offset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                scale = scale > 1.5 ? 1.0 : 2.5
                                lastScale = scale
                                if scale == 1.0 {
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }

                    case .empty:
                        ProgressView()

                    default:
                        Image(systemName: "map")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .accessibilityLabel("Custom venue map. Double tap to zoom. Pinch to zoom in and out.")
    }

    private func pinMarker(_ pin: MapPin) -> some View {
        VStack(spacing: 1) {
            Image(systemName: pin.pinType.systemImage)
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
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
        case .custom: return .gray
        }
    }
}
