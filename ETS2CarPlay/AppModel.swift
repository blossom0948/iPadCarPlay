import Combine
import PhotosUI
import SwiftUI
import SwiftData
import UIKit
import MusicKit
import UserNotifications

enum AppSection: String, CaseIterable, Codable, Identifiable, Hashable {
    case dashboard
    case apps
    case navigation
    case music
    case youtube
    case phone
    case messages
    case voice
    case stats
    case controls
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "대시보드"
        case .apps: "앱"
        case .navigation: "지도"
        case .music: "음악"
        case .youtube: "YouTube"
        case .phone: "가상 전화"
        case .messages: "알림 센터"
        case .voice: "음성 비서"
        case .stats: "운행 통계"
        case .controls: "트럭 제어"
        case .settings: "설정"
        }
    }

    var symbol: String {
        switch self {
        case .dashboard: "rectangle.split.2x1.fill"
        case .apps: "square.grid.2x2.fill"
        case .navigation: "map.fill"
        case .music: "music.note"
        case .youtube: "play.rectangle.fill"
        case .phone: "phone.fill"
        case .messages: "bubble.left.and.bubble.right.fill"
        case .voice: "mic.fill"
        case .stats: "chart.bar.fill"
        case .controls: "steeringwheel"
        case .settings: "gearshape.fill"
        }
    }

    var color: Color {
        switch self {
        case .dashboard: Color(red: 0.28, green: 0.70, blue: 1.00)
        case .apps: Color(red: 0.53, green: 0.58, blue: 1.00)
        case .navigation: Color(red: 0.28, green: 0.79, blue: 0.65)
        case .music: Color(red: 1.00, green: 0.40, blue: 0.52)
        case .youtube: Color(red: 1.00, green: 0.28, blue: 0.25)
        case .phone: Color(red: 0.26, green: 0.82, blue: 0.48)
        case .messages: Color(red: 0.28, green: 0.82, blue: 0.48)
        case .voice: Color(red: 0.37, green: 0.67, blue: 0.98)
        case .stats: Color(red: 1.00, green: 0.66, blue: 0.28)
        case .controls: Color(red: 0.34, green: 0.72, blue: 0.98)
        case .settings: Color(red: 0.66, green: 0.69, blue: 0.75)
        }
    }

    static let launcherItems: [AppSection] = [
        .dashboard, .navigation, .music, .youtube, .phone, .messages, .voice, .stats, .controls, .settings
    ]
}

enum SettingsCategory: String, CaseIterable, Identifiable, Hashable {
    case wallpaper
    case apps
    case general
    case display
    case sound
    case alerts
    case connection
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wallpaper: "배경화면"
        case .apps: "앱 정리"
        case .general: "일반"
        case .display: "디스플레이"
        case .sound: "소리 및 햅틱"
        case .alerts: "알림"
        case .connection: "ETS2 연결"
        case .about: "앱 정보"
        }
    }

    var symbol: String {
        switch self {
        case .wallpaper: "photo.fill"
        case .apps: "square.grid.2x2.fill"
        case .general: "gearshape.2.fill"
        case .display: "sun.max.fill"
        case .sound: "speaker.wave.2.fill"
        case .alerts: "bell.badge.fill"
        case .connection: "network"
        case .about: "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .wallpaper: .indigo
        case .apps: .purple
        case .general: .gray
        case .display: .orange
        case .sound: .pink
        case .alerts: .orange
        case .connection: .green
        case .about: .blue
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: AppSection = .apps
    @Published private(set) var notifications: [InboxMessage] = []
    @Published private(set) var lastVoiceResponse: String?
    @Published private(set) var commandFeedback: String?

    let bridge = BridgeConnectionManager()
    let audio = LocalAudioPlayer()
    let voice = VoiceAssistant()
    private var tripRecorder: TripRecorder?
    private var activeAlertKeys = Set<String>()

    init() {
        notifications = Self.loadNotifications()
        bridge.onSnapshot = { [weak self] snapshot in self?.receive(snapshot) }
        bridge.onGameEvent = { [weak self] event in self?.receive(event) }
    }

    func attach(modelContext: ModelContext) {
        tripRecorder = TripRecorder(modelContext: modelContext)
    }

    func finishTrip() {
        tripRecorder?.finish()
    }

    var hasActiveTrip: Bool { tripRecorder?.hasActiveTrip == true }

    var currentSnapshot: TelemetrySnapshot? { bridge.snapshot }

    func handleVoiceCommand(_ rawText: String) async -> String {
        let command = rawText.lowercased()
        let snapshot = bridge.snapshot

        if command.contains("속도") {
            guard let speed = snapshot?.speedKph else { return "현재 ETS2 속도를 받을 수 없습니다." }
            let value = UserDefaults.standard.string(forKey: "speedUnit") == "mph" ? speed / 1.609344 : speed
            let unit = UserDefaults.standard.string(forKey: "speedUnit") ?? "km/h"
            return "현재 속도는 \(Int(abs(value).rounded())) \(unit)입니다."
        }
        if command.contains("연료") {
            guard let fuel = snapshot?.fuelLiters else { return "현재 연료 정보를 받을 수 없습니다." }
            return "연료가 \(fuel.formatted(.number.precision(.fractionLength(0...1))))리터 남았습니다."
        }
        if command.contains("목적지") || command.contains("남은 거리") || command.contains("도착") {
            guard let snapshot else { return "ETS2 주행 데이터가 연결되지 않았습니다." }
            let city = snapshot.destinationCity ?? "목적지 정보 없음"
            let distance = snapshot.navigationDistanceKm.map { "남은 거리는 \($0.formatted(.number.precision(.fractionLength(0...1))))킬로미터입니다." } ?? "남은 거리 정보가 없습니다."
            let eta = snapshot.navigationEtaSeconds.map { "예상 시간은 \(Int($0 / 60))분입니다." } ?? "예상 시간 정보가 없습니다."
            return "목적지는 \(city)입니다. \(distance) \(eta)"
        }
        if command.contains("벌금") || command.contains("알림") || command.contains("메시지") {
            guard let newest = notifications.first else { return "아직 ETS2 알림이 없습니다." }
            return "\(newest.title). \(newest.detail)"
        }
        if command.contains("일시정지") || command.contains("음악 정지") || command.contains("음악 멈춰") {
            let applePlayer = ApplicationMusicPlayer.shared
            if applePlayer.queue.currentEntry != nil {
                applePlayer.pause()
                return "Apple Music을 일시정지했습니다."
            }
            guard audio.currentTrack != nil else { return "재생 중인 음악이 없습니다." }
            audio.pause()
            return "음악을 일시정지했습니다."
        }
        if command.contains("재생") || command.contains("음악") {
            let applePlayer = ApplicationMusicPlayer.shared
            if applePlayer.queue.currentEntry != nil {
                do {
                    try await applePlayer.play()
                    return "Apple Music을 재생합니다."
                } catch {
                    return "Apple Music 재생을 시작하지 못했습니다."
                }
            }
            guard audio.currentTrack != nil else { return "먼저 음악 화면에서 재생할 파일을 선택해 주세요." }
            audio.resume()
            return "음악을 재생합니다."
        }
        if command.contains("경적") {
            let (_, result) = await bridge.sendCommand("horn")
            return result
        }
        if command.contains("라이트") || command.contains("전조등") {
            let (_, result) = await bridge.sendCommand("lights.toggle")
            return result
        }
        return "속도, 연료, 목적지, 남은 거리, 알림 읽기, 음악 재생, 경적, 라이트를 요청할 수 있습니다."
    }

    func receive(_ snapshot: TelemetrySnapshot) {
        tripRecorder?.ingest(snapshot)
        guard snapshot.gameActive, !snapshot.paused else {
            activeAlertKeys.removeAll()
            return
        }

        let fuelThreshold = UserDefaults.standard.object(forKey: "alerts.fuel.threshold") as? Double ?? 15
        let speedTolerance = UserDefaults.standard.object(forKey: "alerts.speed.tolerance") as? Double ?? 5
        if let fuel = snapshot.fuelPercent, fuel <= fuelThreshold,
           UserDefaults.standard.object(forKey: "alerts.fuel.enabled") as? Bool != false {
            addThresholdAlert(key: "fuel", title: "연료 부족", detail: "연료가 \(Int(fuel.rounded()))% 남았습니다.", level: fuel <= 7 ? .urgent : .warning)
        } else {
            activeAlertKeys.remove("fuel")
        }

        if let speed = snapshot.speedKph, let limit = snapshot.speedLimitKph, speed > limit + speedTolerance,
           UserDefaults.standard.object(forKey: "alerts.speed.enabled") as? Bool != false {
            addThresholdAlert(key: "speed", title: "제한 속도 초과", detail: "현재 \(Int(speed.rounded())) km/h · 제한 \(Int(limit.rounded())) km/h", level: .warning)
        } else {
            activeAlertKeys.remove("speed")
        }

        let highestWear = [snapshot.engineWear, snapshot.transmissionWear, snapshot.cabinWear, snapshot.chassisWear]
            .compactMap { $0 }.max()
        if let wear = highestWear, wear >= 0.12,
           UserDefaults.standard.object(forKey: "alerts.wear.enabled") as? Bool != false {
            addThresholdAlert(key: "wear", title: "차량 정비 확인", detail: "차량 손상도가 \(Int((wear * 100).rounded()))%입니다.", level: wear >= 0.25 ? .urgent : .warning)
        } else {
            activeAlertKeys.remove("wear")
        }
    }

    func receive(_ event: GameEvent) {
        tripRecorder?.ingest(event)
        let message: InboxMessage
        switch event.eventId {
        case "job.delivered":
            let revenue = event.attributes["revenue"].map { "수익 \($0)" }
            message = InboxMessage(title: "배송 완료", detail: ([event.attributes["distance.km"].map { "\($0) km 운행" }, revenue].compactMap { $0 }).joined(separator: " · "), symbol: "checkmark.seal.fill", level: .information, date: event.happenedAt)
        case "player.fined":
            let amount = event.attributes["fine.amount"].map { "벌금 \($0)" } ?? "벌금 이벤트"
            let offence = event.attributes["fine.offence"].map { " · \($0)" } ?? ""
            message = InboxMessage(title: "벌금 기록", detail: amount + offence, symbol: "exclamationmark.triangle.fill", level: .warning, date: event.happenedAt)
        case "player.tollgate.paid":
            let amount = event.attributes["pay.amount"].map { "요금 \($0)" } ?? "통행료 결제"
            message = InboxMessage(title: "톨게이트 통과", detail: amount, symbol: "road.lanes.curved.left", level: .information, date: event.happenedAt)
        case "player.use.ferry", "player.use.train":
            message = InboxMessage(title: "운송 이벤트", detail: event.eventId, symbol: "ferry.fill", level: .information, date: event.happenedAt)
        default:
            message = InboxMessage(title: "ETS2 이벤트", detail: event.eventId, symbol: "bell.fill", level: .information, date: event.happenedAt)
        }
        insert(message)
    }

    func addThresholdAlert(key: String, title: String, detail: String, level: TruckAlert.Level) {
        guard activeAlertKeys.insert(key).inserted else { return }
        insert(InboxMessage(title: title, detail: detail, symbol: "exclamationmark.triangle.fill", level: level, date: .now))
    }

    func addVoiceResponse(_ response: String) {
        lastVoiceResponse = response
    }

    func sendControl(_ name: String, phase: String = "tap") {
        Task {
            let (_, message) = await bridge.sendCommand(name, phase: phase)
            commandFeedback = message
        }
    }

    private func insert(_ message: InboxMessage) {
        notifications.insert(message, at: 0)
        notifications = Array(notifications.prefix(150))
        if let data = try? JSONEncoder().encode(notifications) {
            UserDefaults.standard.set(data, forKey: "ets2.notifications.v1")
        }
        guard UserDefaults.standard.bool(forKey: "alerts.system.enabled") else { return }
        let content = UNMutableNotificationContent()
        content.title = message.title
        content.body = message.detail
        content.sound = .default
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: message.id.uuidString, content: content, trigger: nil)
        )
    }

    private static func loadNotifications() -> [InboxMessage] {
        guard let data = UserDefaults.standard.data(forKey: "ets2.notifications.v1"),
              let messages = try? JSONDecoder().decode([InboxMessage].self, from: data) else { return [] }
        return messages
    }
}

struct InboxMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let symbol: String
    let level: TruckAlert.Level
    let date: Date

    init(title: String, detail: String, symbol: String, level: TruckAlert.Level, date: Date) {
        id = UUID()
        self.title = title
        self.detail = detail.isEmpty ? "실제 이벤트가 수신되었습니다." : detail
        self.symbol = symbol
        self.level = level
        self.date = date
    }
}

enum WallpaperPreset: String, CaseIterable, Identifiable, Hashable {
    case aurora
    case ocean
    case sunset
    case bloom
    case violet
    case midnight

    var id: String { rawValue }

    var name: String {
        switch self {
        case .aurora: "오로라"
        case .ocean: "블루 오션"
        case .sunset: "선셋 글로우"
        case .bloom: "소프트 블룸"
        case .violet: "바이올렛 웨이브"
        case .midnight: "미드나이트"
        }
    }

    var colors: [Color] {
        switch self {
        case .aurora:
            [Color(red: 0.04, green: 0.15, blue: 0.35), Color(red: 0.12, green: 0.35, blue: 0.48), Color(red: 0.35, green: 0.18, blue: 0.55)]
        case .ocean:
            [Color(red: 0.02, green: 0.24, blue: 0.47), Color(red: 0.05, green: 0.53, blue: 0.66), Color(red: 0.18, green: 0.76, blue: 0.76)]
        case .sunset:
            [Color(red: 0.30, green: 0.12, blue: 0.39), Color(red: 0.80, green: 0.27, blue: 0.42), Color(red: 1.00, green: 0.61, blue: 0.30)]
        case .bloom:
            [Color(red: 0.37, green: 0.18, blue: 0.48), Color(red: 0.81, green: 0.37, blue: 0.63), Color(red: 1.00, green: 0.69, blue: 0.67)]
        case .violet:
            [Color(red: 0.10, green: 0.08, blue: 0.35), Color(red: 0.34, green: 0.23, blue: 0.70), Color(red: 0.66, green: 0.37, blue: 0.76)]
        case .midnight:
            [Color(red: 0.02, green: 0.12, blue: 0.18), Color(red: 0.06, green: 0.32, blue: 0.31), Color(red: 0.20, green: 0.47, blue: 0.39)]
        }
    }

    var accent: Color { colors[2] }
}

@MainActor
final class WallpaperStore: ObservableObject {
    @Published private(set) var customImage: UIImage?
    private let fileURL: URL

    init() {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        fileURL = supportDirectory.appendingPathComponent("custom-wallpaper.jpg")
        if let data = try? Data(contentsOf: fileURL) {
            customImage = UIImage(data: data)
        }
    }

    func importPhoto(from item: PhotosPickerItem) async -> Bool {
        guard
            let data = try? await item.loadTransferable(type: Data.self),
            let image = UIImage(data: data),
            let jpegData = image.jpegData(compressionQuality: 0.88)
        else {
            return false
        }

        do {
            let directory = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try jpegData.write(to: fileURL, options: .atomic)
            customImage = image
            return true
        } catch {
            return false
        }
    }
}
