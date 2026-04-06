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
        HStack(spacing: 0) {
            // Left spacer (proportional to lower fraction)
            Color.clear
                .frame(width: 0)

            GeometryReader { geo in
                let w = geo.size.width
                let leftX = lowerFraction * w
                let rightX = upperFraction * w

                // Track background
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity)
                    .position(x: w / 2, y: 10)

                // Active range
                Capsule()
                    .fill(Color.green)
                    .frame(width: max(rightX - leftX, 2), height: 4)
                    .position(x: (leftX + rightX) / 2, y: 10)

                // Lower thumb
                Circle()
                    .fill(isDraggingLower ? Color.green : Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .position(x: leftX, y: 10)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingLower = true
                                let frac = max(0, min(value.location.x / w, upperFraction - 0.01))
                                range = dateAt(fraction: frac)...range.upperBound
                            }
                            .onEnded { _ in isDraggingLower = false }
                    )

                // Upper thumb
                Circle()
                    .fill(isDraggingUpper ? Color.green : Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: .black.opacity(0.25), radius: 2)
                    .position(x: rightX, y: 10)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDraggingUpper = true
                                let frac = max(lowerFraction + 0.01, min(1, value.location.x / w))
                                range = range.lowerBound...dateAt(fraction: frac)
                            }
                            .onEnded { _ in isDraggingUpper = false }
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 22)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Date range from \(range.lowerBound.formatted(.dateTime.month(.abbreviated).day())) to \(range.upperBound.formatted(.dateTime.month(.abbreviated).day()))")
    }
}
