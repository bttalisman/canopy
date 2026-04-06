import SwiftUI

struct DateRangeSlider: View {
    @Binding var range: ClosedRange<Date>
    let bounds: ClosedRange<Date>

    private var totalSeconds: TimeInterval {
        bounds.upperBound.timeIntervalSince(bounds.lowerBound)
    }

    private var lowerValue: Double {
        get { range.lowerBound.timeIntervalSince(bounds.lowerBound) }
    }

    private var upperValue: Double {
        get { range.upperBound.timeIntervalSince(bounds.lowerBound) }
    }

    var body: some View {
        VStack(spacing: 4) {
            // Start date slider
            HStack(spacing: 8) {
                Text("From")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
                Slider(value: Binding(
                    get: { lowerValue },
                    set: { newVal in
                        let clamped = min(newVal, upperValue - 86400)
                        let newDate = bounds.lowerBound.addingTimeInterval(max(0, clamped))
                        range = newDate...range.upperBound
                    }
                ), in: 0...totalSeconds)
                .tint(.green)
            }

            // End date slider
            HStack(spacing: 8) {
                Text("To")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)
                Slider(value: Binding(
                    get: { upperValue },
                    set: { newVal in
                        let clamped = max(newVal, lowerValue + 86400)
                        let newDate = bounds.lowerBound.addingTimeInterval(min(totalSeconds, clamped))
                        range = range.lowerBound...newDate
                    }
                ), in: 0...totalSeconds)
                .tint(.green)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Date range from \(range.lowerBound.formatted(.dateTime.month(.abbreviated).day())) to \(range.upperBound.formatted(.dateTime.month(.abbreviated).day()))")
    }
}
