import SwiftUI

struct WeatherBadgeView: View {
    let latitude: Double
    let longitude: Double
    let date: Date

    @State private var forecast: DayForecast?

    private var isWithinForecastRange: Bool {
        date <= Date().addingTimeInterval(14 * 86400)
    }

    var body: some View {
        Group {
            if let forecast {
                HStack(spacing: 4) {
                    Image(systemName: forecast.sfSymbol)
                        .font(.caption2)
                    Text("\(Int(forecast.high))°")
                        .font(.caption2)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(forecast.description), high of \(Int(forecast.high)) degrees")
            }
        }
        .task {
            guard isWithinForecastRange else { return }
            do {
                let response = try await WeatherService.shared.fetchForecast(
                    latitude: latitude, longitude: longitude
                )
                forecast = WeatherService.shared.forecast(from: response, for: date)
            } catch {
                // Silently fail — weather is non-critical
            }
        }
    }
}
