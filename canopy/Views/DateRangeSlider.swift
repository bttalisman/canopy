import SwiftUI

struct DateRangeSlider: View {
    @Binding var range: ClosedRange<Date>
    let bounds: ClosedRange<Date>

    @State private var isDraggingLower = false
    @State private var isDraggingUpper = false

    private var totalSeconds: TimeInterval {
        bounds.upperBound.timeIntervalSince(bounds.lowerBound)
    }

    private var lowerFraction: CGFloat {
        guard totalSeconds > 0 else { return 0 }
        return CGFloat(range.lowerBound.timeIntervalSince(bounds.lowerBound) / totalSeconds)
    }

    private var upperFraction: CGFloat {
        guard totalSeconds > 0 else { return 1 }
        return CGFloat(range.upperBound.timeIntervalSince(bounds.lowerBound) / totalSeconds)
    }

    private func dateAt(fraction: CGFloat) -> Date {
        let clamped = max(0, min(1, fraction))
        return bounds.lowerBound.addingTimeInterval(totalSeconds * Double(clamped))
    }

    var body: some View {
        GeometryReader { geo in
            let thumbRadius: CGFloat = 10
            let trackWidth = geo.size.width - thumbRadius * 2
            let lowerX = thumbRadius + lowerFraction * trackWidth
            let upperX = thumbRadius + upperFraction * trackWidth

            ZStack(alignment: .leading) {
                // Track background
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(.systemGray4))
                    .frame(height: 4)
                    .padding(.horizontal, thumbRadius)

                // Active range
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.green)
                    .frame(width: max(upperX - lowerX, 0), height: 4)
                    .offset(x: lowerX)

                // Lower thumb
                Circle()
                    .fill(isDraggingLower ? Color.green : Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .offset(x: lowerX - thumbRadius)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingLower = true
                                let fraction = max(0, min((value.location.x - thumbRadius) / trackWidth, upperFraction - 0.02))
                                range = dateAt(fraction: fraction)...range.upperBound
                            }
                            .onEnded { _ in isDraggingLower = false }
                    )

                // Upper thumb
                Circle()
                    .fill(isDraggingUpper ? Color.green : Color.white)
                    .frame(width: thumbRadius * 2, height: thumbRadius * 2)
                    .shadow(color: .black.opacity(0.2), radius: 2)
                    .offset(x: upperX - thumbRadius)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDraggingUpper = true
                                let fraction = max(lowerFraction + 0.02, min(1, (value.location.x - thumbRadius) / trackWidth))
                                range = range.lowerBound...dateAt(fraction: fraction)
                            }
                            .onEnded { _ in isDraggingUpper = false }
                    )
            }
        }
        .frame(height: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Date range from \(range.lowerBound.formatted(.dateTime.month(.abbreviated).day())) to \(range.upperBound.formatted(.dateTime.month(.abbreviated).day()))")
    }
}
