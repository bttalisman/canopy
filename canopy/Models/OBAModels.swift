@preconcurrency import Foundation

struct OBAResponse<T: Decodable & Sendable>: Decodable, Sendable {
    let data: T
}

struct OBAStopListData: Decodable, Sendable {
    let list: [OBAStop]
}

struct OBAStop: Decodable, Sendable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let routeIds: [String]?
}

struct OBAArrivalEntryData: Decodable, Sendable {
    let entry: OBAArrivalEntry
}

struct OBAArrivalEntry: Decodable, Sendable {
    let arrivalsAndDepartures: [OBAArrival]
}

struct OBAArrival: Decodable, Sendable {
    let routeId: String?
    let routeShortName: String?
    let tripHeadsign: String?
    let predictedArrivalTime: Int64
    let scheduledArrivalTime: Int64
    let predicted: Bool
}
