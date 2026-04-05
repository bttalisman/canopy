import Foundation
import CoreLocation

// MARK: - App Models

struct TransitRoute: Identifiable {
    let id = UUID()
    let steps: [TransitStep]
    let totalTravelTime: TimeInterval
    let expectedDepartureTime: Date
    let expectedArrivalTime: Date

    var summary: String {
        let transitSteps = steps.filter { $0.transportType != .walk }
        if transitSteps.isEmpty { return "Walk" }
        return transitSteps.compactMap(\.lineName).joined(separator: " → ")
    }

    var totalMinutes: Int {
        Int(totalTravelTime / 60)
    }
}

struct TransitStep: Identifiable {
    let id = UUID()
    let instruction: String
    let transportType: TransitStepType
    let lineName: String?
    let departureStopName: String?
    let arrivalStopName: String?
    let distance: Double? // meters
    let duration: TimeInterval

    var durationMinutes: Int {
        Int(duration / 60)
    }
}

enum TransitStepType: String {
    case walk
    case bus
    case train
    case ferry
    case other

    var sfSymbol: String {
        switch self {
        case .walk: return "figure.walk"
        case .bus: return "bus.fill"
        case .train: return "tram.fill"
        case .ferry: return "ferry.fill"
        case .other: return "arrow.turn.up.right"
        }
    }

    var color: String {
        switch self {
        case .walk: return "secondary"
        case .bus: return "green"
        case .train: return "blue"
        case .ferry: return "cyan"
        case .other: return "gray"
        }
    }
}

struct RealTimeArrival: Identifiable {
    let id = UUID()
    let routeId: String
    let routeName: String
    let headsign: String
    let minutesUntilArrival: Int
    let isRealTime: Bool
    let stopName: String
}

// MARK: - OpenTripPlanner API Response Models

struct OTPResponse: Codable {
    let plan: OTPPlan?
}

struct OTPPlan: Codable {
    let itineraries: [OTPItinerary]
}

struct OTPItinerary: Codable {
    let duration: Int // seconds
    let startTime: Int64 // epoch ms
    let endTime: Int64 // epoch ms
    let legs: [OTPLeg]
}

struct OTPLeg: Codable {
    let mode: String // WALK, BUS, RAIL, TRAM, FERRY
    let route: String?
    let routeShortName: String?
    let duration: Double // seconds
    let distance: Double // meters
    let from: OTPPlace
    let to: OTPPlace
}

struct OTPPlace: Codable {
    let name: String
    let lat: Double?
    let lon: Double?
}

// MARK: - OneBusAway API Response Models

struct OBAResponse<T: Codable>: Codable {
    let data: T
}

struct OBAStopListData: Codable {
    let list: [OBAStop]
}

struct OBAStop: Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let routeIds: [String]?
}

struct OBAArrivalEntryData: Codable {
    let entry: OBAArrivalEntry
}

struct OBAArrivalEntry: Codable {
    let arrivalsAndDepartures: [OBAArrival]
}

struct OBAArrival: Codable {
    let routeId: String?
    let routeShortName: String?
    let tripHeadsign: String?
    let predictedArrivalTime: Int64
    let scheduledArrivalTime: Int64
    let predicted: Bool
}
