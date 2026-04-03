import SwiftUI

struct WeatherForecastView: View {
    let latitude: Double
    let longitude: Double
    let startDate: Date
    let endDate: Date

    @State private var forecasts: [DayForecast] = []
    @State private var isLoading = true

    private var isWithinForecastRange: Bool {
        startDate <= Date().addingTimeInterval(14 * 86400)
    }

    var body: some View {
        Group {
            if !forecasts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Forecast", systemImage: "cloud.sun.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if forecasts.count == 1, let day = forecasts.first {
                        // Single-day: compact inline row
                        HStack(spacing: 12) {
                            Image(systemName: day.sfSymbol)
                                .font(.title2)
                                .foregroundStyle(iconColor(for: day.weatherCode))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(day.description)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                HStack(spacing: 8) {
                                    Text("H: \(Int(day.high))°")
                                        .font(.caption)
                                    Text("L: \(Int(day.low))°")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if day.precipProbability > 0 {
                                        HStack(spacing: 2) {
                                            Image(systemName: "drop.fill")
                                                .font(.system(size: 9))
                                            Text("\(day.precipProbability)%")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.blue)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        // Multi-day: horizontal scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(forecasts, id: \.date) { day in
                                    VStack(spacing: 6) {
                                        Text(day.date, format: .dateTime.weekday(.abbreviated))
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.secondary)

                                        Image(systemName: day.sfSymbol)
                                            .font(.title3)
                                            .foregroundStyle(iconColor(for: day.weatherCode))

                                        Text("\(Int(day.high))°")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)

                                        Text("\(Int(day.low))°")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)

                                        if day.precipProbability > 0 {
                                            HStack(spacing: 2) {
                                                Image(systemName: "drop.fill")
                                                    .font(.system(size: 8))
                                                Text("\(day.precipProbability)%")
                                                    .font(.system(size: 10))
                                            }
                                            .foregroundStyle(.blue)
                                        }
                                    }
                                    .frame(width: 58)
                                    .padding(.vertical, 10)
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else if isLoading && isWithinForecastRange {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        }
        .task {
            guard isWithinForecastRange else {
                isLoading = false
                return
            }
            do {
                let response = try await WeatherService.shared.fetchForecast(
                    latitude: latitude, longitude: longitude
                )
                forecasts = WeatherService.shared.forecasts(
                    from: response, startDate: startDate, endDate: endDate
                )
            } catch {
                // Silently fail
            }
            isLoading = false
        }
    }

    private func iconColor(for code: Int) -> Color {
        switch code {
        case 0, 1: return .yellow
        case 2, 3: return .gray
        case 45, 48: return .gray
        case 51...67: return .blue
        case 71...77: return .cyan
        case 80...82: return .blue
        case 95...99: return .purple
        default: return .gray
        }
    }
}
