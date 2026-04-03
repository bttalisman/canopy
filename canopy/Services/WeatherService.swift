import Foundation

// MARK: - Models

struct WeatherResponse: Codable {
    let daily: DailyWeather
}

struct DailyWeather: Codable {
    let time: [String]
    let temperature_2m_max: [Double]
    let temperature_2m_min: [Double]
    let precipitation_probability_max: [Int]
    let weathercode: [Int]
}

struct DayForecast {
    let date: Date
    let high: Double
    let low: Double
    let precipProbability: Int
    let weatherCode: Int

    var sfSymbol: String { WeatherCodeMapper.sfSymbol(for: weatherCode) }
    var description: String { WeatherCodeMapper.description(for: weatherCode) }
}

// MARK: - Weather Code Mapper

enum WeatherCodeMapper {
    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.min.fill"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65: return "cloud.heavyrain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75, 77: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow Grains"
        case 80, 81, 82: return "Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm w/ Hail"
        default: return "Unknown"
        }
    }
}

// MARK: - Service

actor WeatherService {
    static let shared = WeatherService()

    private let session = URLSession.shared
    private let decoder = JSONDecoder()
    private var cache: [String: CachedForecast] = [:]

    private struct CachedForecast {
        let response: WeatherResponse
        let fetchedAt: Date
    }

    private func cacheKey(lat: Double, lng: Double) -> String {
        let rlat = (lat * 100).rounded() / 100
        let rlng = (lng * 100).rounded() / 100
        return "\(rlat)_\(rlng)"
    }

    func fetchForecast(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        let key = cacheKey(lat: latitude, lng: longitude)

        if let cached = cache[key], Date().timeIntervalSince(cached.fetchedAt) < 3600 {
            return cached.response
        }

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weathercode"),
            URLQueryItem(name: "timezone", value: "America/Los_Angeles"),
            URLQueryItem(name: "forecast_days", value: "14"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
        ]

        guard let url = components.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw WeatherError.serverError
        }

        let weatherResponse = try decoder.decode(WeatherResponse.self, from: data)
        cache[key] = CachedForecast(response: weatherResponse, fetchedAt: Date())
        return weatherResponse
    }

    nonisolated func forecasts(from response: WeatherResponse, startDate: Date, endDate: Date) -> [DayForecast] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let calendar = Calendar.current

        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)

        return zip(response.daily.time, response.daily.time.indices).compactMap { dateStr, i in
            guard let date = dateFormatter.date(from: dateStr) else { return nil }
            let day = calendar.startOfDay(for: date)
            guard day >= start && day <= end else { return nil }
            guard i < response.daily.temperature_2m_max.count,
                  i < response.daily.temperature_2m_min.count,
                  i < response.daily.precipitation_probability_max.count,
                  i < response.daily.weathercode.count else { return nil }

            return DayForecast(
                date: date,
                high: response.daily.temperature_2m_max[i],
                low: response.daily.temperature_2m_min[i],
                precipProbability: response.daily.precipitation_probability_max[i],
                weatherCode: response.daily.weathercode[i]
            )
        }
    }

    nonisolated func forecast(from response: WeatherResponse, for date: Date) -> DayForecast? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let target = dateFormatter.string(from: date)

        guard let idx = response.daily.time.firstIndex(of: target) else { return nil }
        guard idx < response.daily.temperature_2m_max.count else { return nil }

        return DayForecast(
            date: date,
            high: response.daily.temperature_2m_max[idx],
            low: response.daily.temperature_2m_min[idx],
            precipProbability: response.daily.precipitation_probability_max[idx],
            weatherCode: response.daily.weathercode[idx]
        )
    }
}

enum WeatherError: LocalizedError {
    case invalidURL
    case serverError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid weather API URL."
        case .serverError: return "Weather service unavailable."
        }
    }
}
