@preconcurrency import Foundation

struct OBAStopsResponse: Decodable {
    let data: OBAStopListData
}

struct OBAArrivalsResponse: Decodable {
    let data: OBAArrivalEntryData
}

struct OBAStopListData: Decodable {
    let list: [OBAStop]
}

struct OBAStop: Decodable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let routeIds: [String]?
}

struct OBAArrivalEntryData: Decodable {
    let entry: OBAArrivalEntry
}

struct OBAArrivalEntry: Decodable {
    let arrivalsAndDepartures: [OBAArrival]
}

struct OBAArrival: Decodable {
    let routeId: String?
    let routeShortName: String?
    let tripHeadsign: String?
    let predictedArrivalTime: Int64
    let scheduledArrivalTime: Int64
    let predicted: Bool
}
