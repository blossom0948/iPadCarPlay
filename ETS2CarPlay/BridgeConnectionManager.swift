import Foundation
import Combine
import Security

@MainActor
final class BridgeConnectionManager: ObservableObject {
    @Published private(set) var status: BridgeConnectionStatus = .notConfigured
    @Published private(set) var gameState: GameConnectionState = .waitingForGame
    @Published private(set) var snapshot: TelemetrySnapshot?
    @Published private(set) var events: [GameEvent] = []
    @Published private(set) var lastCommandMessage: String?

    var onSnapshot: ((TelemetrySnapshot) -> Void)?
    var onGameEvent: ((GameEvent) -> Void)?

    private let session = URLSession(configuration: .default)
    private var socket: URLSessionWebSocketTask?
    private var connectionTask: Task<Void, Never>?
    private var host = ""
    private var port = 8765
    private var pairingCode = ""
    private var hasReceivedTelemetry = false
    private var stopReconnect = false
    private var pendingCommands: [String: CheckedContinuation<(Bool, String), Never>] = [:]

    var isConnected: Bool {
        if case .connected = status { return true }
        return false
    }

    func connect(host: String, port: Int, pairingCode: String) {
        let cleanHost = Self.normalizedHost(host)
        guard !cleanHost.isEmpty, (1...65_535).contains(port) else {
            status = .notConfigured
            return
        }
        self.host = cleanHost
        self.port = port
        self.pairingCode = pairingCode.trimmingCharacters(in: .whitespacesAndNewlines)
        stopReconnect = false
        failPendingCommands("PC 브리지 연결이 다시 시작되었습니다.")
        connectionTask?.cancel()
        socket?.cancel(with: .goingAway, reason: nil)
        snapshot = nil
        gameState = .waitingForGame
        hasReceivedTelemetry = false
        status = .connecting
        connectionTask = Task { [weak self] in
            await self?.connectionLoop()
        }
    }

    func disconnect() {
        failPendingCommands("브리지 연결이 해제되었습니다.")
        connectionTask?.cancel()
        connectionTask = nil
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
        snapshot = nil
        gameState = .waitingForGame
        hasReceivedTelemetry = false
        status = host.isEmpty ? .notConfigured : .disconnected("연결 해제됨")
    }

    func forgetPairing() {
        KeychainToken.remove(for: host)
        disconnect()
    }

    func sendCommand(_ control: String, phase: String = "tap") async -> (Bool, String) {
        guard isConnected, gameState == .live,
              let snapshot, snapshot.gameActive, !snapshot.paused,
              let socket else {
            let message = "ETS2가 실시간으로 연결된 뒤 조작할 수 있습니다."
            lastCommandMessage = message
            return (false, message)
        }
        let commandId = UUID().uuidString
        let packet: [String: Any] = [
            "type": "command.request",
            "version": 1,
            "commandId": commandId,
            "control": control,
            "phase": phase
        ]
        return await withCheckedContinuation { continuation in
            pendingCommands[commandId] = continuation
            Task { @MainActor in
                do {
                    let data = try JSONSerialization.data(withJSONObject: packet)
                    try await socket.send(.data(data))
                } catch {
                    resumeCommand(commandId, result: (false, "조작 전송 실패: \(error.localizedDescription)"))
                }
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                resumeCommand(commandId, result: (false, "Windows 브리지 응답 시간이 초과되었습니다."))
            }
        }
    }

    private func connectionLoop() async {
        while !Task.isCancelled {
            do {
                guard let url = webSocketURL() else {
                    status = .disconnected("PC 주소를 확인해 주세요")
                    return
                }
                status = .connecting
                let task = session.webSocketTask(with: url)
                socket = task
                task.resume()

                if let token = KeychainToken.read(for: host) {
                    try await send(["type": "auth", "version": 1, "token": token], using: task)
                } else {
                    guard !pairingCode.isEmpty else {
                        status = .disconnected("처음 연결할 때 페어링 코드를 입력해 주세요")
                        task.cancel(with: .goingAway, reason: nil)
                        return
                    }
                    status = .pairing
                    try await send(["type": "pair.request", "version": 1, "code": pairingCode], using: task)
                }

                try await receiveLoop(task)
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled || stopReconnect { return }
                failPendingCommands("PC 브리지 연결이 끊겼습니다.")
                status = .disconnected("PC 브리지 연결을 다시 시도합니다")
                snapshot = nil
                gameState = .stale
            }

            if Task.isCancelled { return }
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func receiveLoop(_ task: URLSessionWebSocketTask) async throws {
        while !Task.isCancelled {
            let message = try await task.receive()
            let data: Data
            switch message {
            case .data(let value): data = value
            case .string(let value): data = Data(value.utf8)
            @unknown default: continue
            }
            let packet = try JSONDecoder().decode(BridgeEnvelope.self, from: data)
            await handle(packet)
        }
    }

    private func handle(_ packet: BridgeEnvelope) async {
        switch packet.type {
        case "pair.accepted":
            if let token = packet.token { KeychainToken.save(token, for: host) }
            status = .connected
            pairingCode = ""
        case "auth.accepted":
            status = .connected
        case "auth.rejected", "pair.rejected":
            failPendingCommands(packet.message ?? "페어링이 거부되었습니다.")
            stopReconnect = true
            if packet.type == "pair.rejected" { pairingCode = "" }
            if packet.type == "auth.rejected" { KeychainToken.remove(for: host) }
            status = .disconnected(packet.message ?? "페어링이 거부되었습니다")
            socket?.cancel(with: .policyViolation, reason: nil)
        case "bridge.status":
            status = .connected
            switch packet.gameState {
            case "live": gameState = .live
            case "paused": gameState = .paused
            case "stale": gameState = hasReceivedTelemetry ? .stale : .waitingForGame
            default: gameState = .waitingForGame
            }
        case "telemetry.snapshot":
            guard let value = packet.data else { return }
            snapshot = value
            hasReceivedTelemetry = true
            gameState = value.paused ? .paused : (value.gameActive ? .live : .waitingForGame)
            onSnapshot?(value)
        case "game.event":
            guard let event = packet.event else { return }
            events.insert(event, at: 0)
            events = Array(events.prefix(100))
            onGameEvent?(event)
        case "command.result":
            let result = (packet.success ?? false, packet.message ?? "Windows 브리지에서 조작 결과를 받지 못했습니다.")
            if let commandId = packet.commandId { resumeCommand(commandId, result: result) }
        default:
            break
        }
    }

    private func send(_ object: [String: Any], using task: URLSessionWebSocketTask) async throws {
        let data = try JSONSerialization.data(withJSONObject: object)
        try await task.send(.data(data))
    }

    private func resumeCommand(_ commandId: String, result: (Bool, String)) {
        guard let continuation = pendingCommands.removeValue(forKey: commandId) else { return }
        lastCommandMessage = result.1
        continuation.resume(returning: result)
    }

    private func failPendingCommands(_ message: String) {
        let pending = pendingCommands
        pendingCommands.removeAll()
        for continuation in pending.values { continuation.resume(returning: (false, message)) }
        lastCommandMessage = message
    }

    private func webSocketURL() -> URL? {
        var components = URLComponents()
        components.scheme = "ws"
        components.host = host
        components.port = port
        components.path = "/ws"
        return components.url
    }

    private static func normalizedHost(_ value: String) -> String {
        var host = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["ws://", "wss://", "http://", "https://"] where host.hasPrefix(prefix) {
            host.removeFirst(prefix.count)
        }
        return host.split(separator: "/", maxSplits: 1).first.map(String.init) ?? host
    }
}

private enum KeychainToken {
    private static let service = "com.blossom0948.ETS2CarPlay.bridge"

    static func save(_ token: String, for host: String) {
        remove(for: host)
        guard let data = token.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func read(for host: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(for host: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: host
        ]
        SecItemDelete(query as CFDictionary)
    }
}
