import SwiftUI

struct DateRangeSlider: View {
    @Binding var range: ClosedRange<Date>
    let bounds: ClosedRange<Date>

    @State private var dragStartLowerFrac: Double?
    @State private var dragStartUpperFrac: Double?
    @State private var activeThumb: Thumb?
    @State private var isPrecision: Bool = false

    private enum Thumb { case lower, upper }

    private var totalSeconds: TimeInterval {
        bounds.upperBound.timeIntervalSince(bounds.lowerBound)
    }

    private var lowerFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return max(0, min(1, range.lowerBound.timeIntervalSince(bounds.lowerBound) / totalSeconds))
    }

    private var upperFraction: Double {
        guard totalSeconds > 0 else { return 1 }
        return max(0, min(1, range.upperBound.timeIntervalSince(bounds.lowerBound) / totalSeconds))
    }

    private func dateAt(_ fraction: Double) -> Date {
        bounds.lowerBound.addingTimeInterval(totalSeconds * max(0, min(1, fraction)))
    }

    /// Snap a date to the start of its day.
    private func snap(_ date: Date) -> Date {
        let snapped = Calendar.current.startOfDay(for: date)
        // Clamp inside bounds
        return min(max(snapped, bounds.lowerBound), bounds.upperBound)
    }

    /// Sensitivity multiplier based on vertical drift away from the track.
    /// Drag horizontally for normal speed; drift vertically for fine control.
    private func sensitivity(for verticalOffset: CGFloat) -> Double {
        let absY = abs(Double(verticalOffset))
        // 0..40pt → full speed; 40..200pt → ramps from 1.0 down to 0.15
        if absY < 40 { return 1.0 }
        let t = min(1.0, (absY - 40) / 160)
        return 1.0 - t * 0.85
    }

    var body: some View {
        Color.clear.frame(height: 28)
            .overlay(
                GeometryReader { geo in
                    let inset: CGFloat = 22
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
                        .fill(Color.leafDeep.opacity(0.65))
                        .frame(width: max(rightX - leftX, 2), height: 4)
                        .position(x: (leftX + rightX) / 2, y: midY)

                    // Lower thumb
                    thumb(active: activeThumb == .lower)
                        .position(x: leftX, y: midY)
                        .overlay(
                            // Floating date label
                            Group {
                                if activeThumb == .lower {
                                    dateLabel(for: range.lowerBound, precision: isPrecision)
                                        .position(x: leftX, y: midY - 34)
                                }
                            }
                        )
                        .overlay(
                            // Larger invisible hit target
                            Color.clear
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .position(x: leftX, y: midY)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { v in
                                            if dragStartLowerFrac == nil {
                                                dragStartLowerFrac = lowerFraction
                                                activeThumb = .lower
                                            }
                                            let s = sensitivity(for: v.translation.height)
                                            isPrecision = s < 0.95
                                            let dx = v.translation.width * CGFloat(s)
                                            let frac = (dragStartLowerFrac ?? 0) + Double(dx / trackW)
                                            let clamped = max(0, min(frac, upperFraction - 0.005))
                                            range = snap(dateAt(clamped))...range.upperBound
                                        }
                                        .onEnded { _ in
                                            dragStartLowerFrac = nil
                                            activeThumb = nil
                                            isPrecision = false
                                        }
                                )
                        )

                    // Upper thumb
                    thumb(active: activeThumb == .upper)
                        .position(x: rightX, y: midY)
                        .overlay(
                            Group {
                                if activeThumb == .upper {
                                    dateLabel(for: range.upperBound, precision: isPrecision)
                                        .position(x: rightX, y: midY - 34)
                                }
                            }
                        )
                        .overlay(
                            Color.clear
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .position(x: rightX, y: midY)
                                .highPriorityGesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { v in
                                            if dragStartUpperFrac == nil {
                                                dragStartUpperFrac = upperFraction
                                                activeThumb = .upper
                                            }
                                            let s = sensitivity(for: v.translation.height)
                                            isPrecision = s < 0.95
                                            let dx = v.translation.width * CGFloat(s)
                                            let frac = (dragStartUpperFrac ?? 1) + Double(dx / trackW)
                                            let clamped = max(lowerFraction + 0.005, min(1, frac))
                                            range = range.lowerBound...snap(dateAt(clamped))
                                        }
                                        .onEnded { _ in
                                            dragStartUpperFrac = nil
                                            activeThumb = nil
                                            isPrecision = false
                                        }
                                )
                        )
                }
            )
    }

    private func thumb(active: Bool) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: active ? 28 : 24, height: active ? 28 : 24)
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .overlay(
                Circle()
                    .fill(Color.leafDeep)
                    .frame(width: active ? 12 : 10, height: active ? 12 : 10)
            )
            .animation(.easeOut(duration: 0.12), value: active)
    }

    private func dateLabel(for date: Date, precision: Bool) -> some View {
        HStack(spacing: 4) {
            if precision {
                Image(systemName: "scope")
                    .font(.system(size: 9, weight: .bold))
            }
            Text(date, format: .dateTime.month(.abbreviated).day())
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.leafDeep)
        )
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .fixedSize()
        .transition(.scale.combined(with: .opacity))
    }
}
