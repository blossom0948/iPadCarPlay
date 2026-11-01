import Foundation

struct GameWorldPosition: Codable, Equatable {
    let x: Double
    let y: Double
    let z: Double
    let headingDegrees: Double?
}

struct TelemetrySnapshot: Codable, Equatable, Identifiable {
    let sequence: UInt64
    let gameActive: Bool
    let paused: Bool
    let speedMps: Double?
    let engineRpm: Double?
    let gear: Int?
    let fuelLiters: Double?
    let fuelCapacityLiters: Double?
    let fuelRangeKm: Double?
    let navigationDistanceMeters: Double?
    let navigationEtaSeconds: Double?
    let navigationSpeedLimitMps: Double?
    let odometerKm: Double?
    let engineWear: Double?
    let transmissionWear: Double?
    let cabinWear: Double?
    let chassisWear: Double?
    let parkingBrake: Bool?
    let leftIndicator: Bool?
    let rightIndicator: Bool?
    let worldPosition: GameWorldPosition?
    let cargo: String?
    let sourceCity: String?
    let destinationCity: String?
    let destinationCompany: String?

    var speedKph: Double? { speedMps.map { $0 * 3.6 } }
    var speedMph: Double? { speedMps.map { $0 * 2.2369362921 } }
    var speedLimitKph: Double? { navigationSpeedLimitMps.map { $0 * 3.6 } }
    var fuelPercent: Double? {
        guard let fuelLiters, let capacity = fuelCapacityLiters, capacity > 0 else { return nil }
        return min(max(fuelLiters / capacity * 100, 0), 100)
    }
    var navigationDistanceKm: Double? { navigationDistanceMeters.map { $0 / 1_000 } }
}

struct GameEvent: Codable, Equatable, Identifiable {
    let eventId: String
    let happenedAtUnixMs: Int64
    let attributes: [String: String]

    var id: String { "\(eventId)-\(happenedAtUnixMs)" }
    var happenedAt: Date { Date(timeIntervalSince1970: Double(happenedAtUnixMs) / 1_000) }
}

struct BridgeEnvelope: Decodable {
    let type: String
    let version: Int?
    let data: TelemetrySnapshot?
    let event: GameEvent?
    let token: String?
    let message: String?
    let gameState: String?
    let commandId: String?
    let success: Bool?
}

enum BridgeConnectionStatus: Equatable {
    case notConfigured
    case connecting
    case pairing
    case connected
    case disconnected(String)

    var label: String {
        switch self {
        case .notConfigured: "PC 주소 필요"
        case .connecting: "연결 중"
        case .pairing: "페어링 중"
        case .connected: "PC 브리지 연결됨"
        case .disconnected(let message): message
        }
    }
}

enum GameConnectionState: Equatable {
    case waitingForGame
    case live
    case paused
    case stale

    var label: String {
        switch self {
        case .waitingForGame: "ETS2 실행 대기"
        case .live: "ETS2 실시간 연결"
        case .paused: "게임 일시정지"
        case .stale: "텔레메트리 갱신 중단"
        }
    }
}

struct TruckAlert: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let level: Level
    let date: Date

    enum Level: String, Codable {
        case information
        case warning
        case urgent
    }

    init(title: String, detail: String, level: Level, date: Date = .now) {
        id = UUID()
        self.title = title
        self.detail = detail
        self.level = level
        self.date = date
    }
}
