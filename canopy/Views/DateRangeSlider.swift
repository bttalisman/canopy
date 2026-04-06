import SwiftUI

struct DateRangeSlider: View {
    @Binding var range: ClosedRange<Date>
    let bounds: ClosedRange<Date>

    private var totalSeconds: TimeInterval {
        bounds.upperBound.timeIntervalSince(bounds.lowerBound)
    }

    private var lowerFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return range.lowerBound.timeIntervalSince(bounds.lowerBound) / totalSeconds
    }

    private var upperFraction: Double {
        guard totalSeconds > 0 else { return 1 }
        return range.upperBound.timeIntervalSince(bounds.lowerBound) / totalSeconds
    }

    private func dateAt(_ fraction: Double) -> Date {
        bounds.lowerBound.addingTimeInterval(totalSeconds * max(0, min(1, fraction)))
    }

    var body: some View {
        // Use a hidden native slider just to get the correct track width
        Color.clear.frame(height: 28)
            .overlay(
                GeometryReader { geo in
                    // Inset by thumb radius so thumbs don't clip
                    let inset: CGFloat = 14
                    let trackW = geo.size.width - inset * 2
                    let leftX = inset + CGFloat(lowerFraction) * trackW
                    let rightX = inset + CGFloat(upperFraction) * trackW
                    let midY = geo.size.height / 2

                    // Track
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                        .position(x: geo.size.width / 2, y: midY)
                        .padding(.horizontal, inset)

                    // Active range
                    Capsule()
                        .fill(Color.green.opacity(0.6))
                        .frame(width: max(rightX - leftX, 2), height: 4)
                        .position(x: (leftX + rightX) / 2, y: midY)

                    // Lower thumb
                    thumb(isDragging: false)
                        .position(x: leftX, y: midY)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let frac = Double((v.location.x - inset) / trackW)
                                    let clamped = max(0, min(frac, upperFraction - 0.01))
                                    range = dateAt(clamped)...range.upperBound
                                }
                        )

                    // Upper thumb
                    thumb(isDragging: false)
                        .position(x: rightX, y: midY)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    let frac = Double((v.location.x - inset) / trackW)
                                    let clamped = max(lowerFraction + 0.01, min(1, frac))
                                    range = range.lowerBound...dateAt(clamped)
                                }
                        )
                }
            )
    }

    private func thumb(isDragging: Bool) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 24, height: 24)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .overlay(
                Circle().fill(Color.green).frame(width: 10, height: 10)
            )
    }
}
