import Foundation
import SwiftData

@Model
final class TripRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var distanceKm: Double
    var fuelUsedLiters: Double
    var maximumSpeedKph: Double
    var averageSpeedKph: Double
    var movingSeconds: Double
    var finesAmount: Double
    var tollsAmount: Double
    var revenueAmount: Double
    var cargo: String?
    var destination: String?
    var delivered: Bool

    init(startedAt: Date = .now, cargo: String? = nil, destination: String? = nil) {
        id = UUID()
        self.startedAt = startedAt
        endedAt = nil
        distanceKm = 0
        fuelUsedLiters = 0
        maximumSpeedKph = 0
        averageSpeedKph = 0
        movingSeconds = 0
        finesAmount = 0
        tollsAmount = 0
        revenueAmount = 0
        self.cargo = cargo
        self.destination = destination
        delivered = false
    }
}

@MainActor
final class TripRecorder {
    private let modelContext: ModelContext
    private var currentTrip: TripRecord?
    private var previousOdometer: Double?
    private var previousFuel: Double?
    private var previousUpdate: Date?
    private var movingSpeedTotal = 0.0
    private var lastSavedAt = Date.distantPast

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        if let records = try? modelContext.fetch(FetchDescriptor<TripRecord>()) {
            currentTrip = records
                .filter { $0.endedAt == nil }
                .max { $0.startedAt < $1.startedAt }
        }
        if let currentTrip, currentTrip.movingSeconds > 0 {
            movingSpeedTotal = currentTrip.averageSpeedKph * currentTrip.movingSeconds
        }
    }

    var hasActiveTrip: Bool { currentTrip != nil }

    func ingest(_ snapshot: TelemetrySnapshot) {
        guard snapshot.gameActive else { return }
        if currentTrip == nil {
            let hasJob = snapshot.cargo != nil || snapshot.destinationCity != nil
            let isMoving = snapshot.speedKph.map { abs($0) > 1 } ?? false
            guard hasJob || isMoving else { return }
            currentTrip = TripRecord(cargo: snapshot.cargo, destination: snapshot.destinationCity)
            if let currentTrip { modelContext.insert(currentTrip) }
        }
        guard let trip = currentTrip else { return }

        if trip.cargo == nil { trip.cargo = snapshot.cargo }
        if trip.destination == nil { trip.destination = snapshot.destinationCity }
        if let odometer = snapshot.odometerKm {
            if let previousOdometer, odometer >= previousOdometer {
                let distance = odometer - previousOdometer
                if distance <= 1.5 { trip.distanceKm += distance }
            }
            previousOdometer = odometer
        }
        if let fuel = snapshot.fuelLiters {
            if let previousFuel, fuel < previousFuel {
                let used = previousFuel - fuel
                if used < 100 { trip.fuelUsedLiters += used }
            }
            previousFuel = fuel
        }
        if let speed = snapshot.speedKph {
            trip.maximumSpeedKph = max(trip.maximumSpeedKph, abs(speed))
            let now = Date.now
            if !snapshot.paused, abs(speed) > 1,
               let previousUpdate, now.timeIntervalSince(previousUpdate) <= 2.5 {
                let delta = now.timeIntervalSince(previousUpdate)
                trip.movingSeconds += delta
                movingSpeedTotal += abs(speed) * delta
                trip.averageSpeedKph = movingSpeedTotal / trip.movingSeconds
            }
            previousUpdate = now
        }
        save()
    }

    func ingest(_ event: GameEvent) {
        guard let trip = currentTrip else { return }
        switch event.eventId {
        case "player.fined":
            trip.finesAmount += numericAttribute("fine.amount", in: event)
        case "player.tollgate.paid":
            trip.tollsAmount += numericAttribute("pay.amount", in: event)
        case "job.delivered":
            trip.delivered = true
            trip.revenueAmount += numericAttribute("revenue", in: event)
            if trip.cargo == nil { trip.cargo = event.attributes["cargo"] }
            finish()
        case "job.cancelled":
            finish()
        default:
            break
        }
        save(force: true)
    }

    func finish() {
        guard let trip = currentTrip else { return }
        trip.endedAt = .now
        currentTrip = nil
        previousOdometer = nil
        previousFuel = nil
        previousUpdate = nil
        movingSpeedTotal = 0
        save(force: true)
    }

    private func numericAttribute(_ key: String, in event: GameEvent) -> Double {
        guard let raw = event.attributes[key] else { return 0 }
        return Double(raw.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    private func save(force: Bool = false) {
        let now = Date.now
        guard force || now.timeIntervalSince(lastSavedAt) >= 5 else { return }
        try? modelContext.save()
        lastSavedAt = now
    }
}
