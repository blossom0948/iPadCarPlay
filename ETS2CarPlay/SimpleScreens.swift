import SwiftUI
import UniformTypeIdentifiers

struct AppsScreen: View {
    @ObservedObject var layoutStore: AppLayoutStore
    let onSelect: (AppSection) -> Void

    private let columns = [GridItem(.adaptive(minimum: 112), spacing: 18)]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 5) {
                Text("앱")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("ETS2 운행을 위한 기능")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
            }

            Group {
                if layoutStore.visibleSections.isEmpty {
                    ContentUnavailableView {
                        Label("표시할 앱이 없습니다", systemImage: "square.grid.2x2")
                    } description: {
                        Text("설정의 앱 정리에서 앱 아이콘을 다시 표시하세요.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .dashboardCard(cornerRadius: 26)
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 18) {
                            ForEach(layoutStore.visibleSections) { section in
                                Button { onSelect(section) } label: {
                                    VStack(spacing: 10) {
                                        AppIconTile(section: section)
                                            .frame(width: 92, height: 92)
                                            .shadow(color: section.color.opacity(0.22), radius: 15, y: 8)
                                        Text(section.title)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                    }
                    .scrollIndicators(.hidden)
                    .dashboardCard(cornerRadius: 26)
                }
            }
        }
    }
}

struct NavigationScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: BridgeConnectionManager
    let speedUnit: String

    init(model: AppModel, speedUnit: String) {
        self.model = model
        bridge = model.bridge
        self.speedUnit = speedUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("내비게이션")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("게임에서 받은 실제 안내 정보")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Label(bridge.gameState.label, systemImage: bridge.isConnected ? "location.fill" : "location.slash.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }

            HStack(spacing: 15) {
                NavigationDataCard(snapshot: bridge.snapshot, gameState: bridge.gameState)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(spacing: 14) {
                    TruckTelemetryCard(snapshot: bridge.snapshot, speedUnit: speedUnit)
                        .frame(maxHeight: .infinity)
                    WorldPositionCard(position: bridge.snapshot?.worldPosition)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 300)
            }

            HStack(spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.cyan)
                Text("SCS 게임 좌표는 위도·경도가 아니므로 외부 지도 위에 도로 경로로 표시하지 않습니다.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Button {
                    let snapshot = bridge.snapshot
                    let answer = snapshot.flatMap { value -> String? in
                        guard let distance = value.navigationDistanceKm else { return nil }
                        return "목적지까지 \(distance.formatted(.number.precision(.fractionLength(0...1))))킬로미터 남았습니다."
                    } ?? "실제 내비게이션 거리를 받을 수 없습니다."
                    model.voice.speak(answer, audioPlayer: model.audio)
                } label: {
                    Label("거리 듣기", systemImage: "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.plain)
                .disabled(bridge.snapshot?.navigationDistanceKm == nil)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 11)
            .dashboardCard(cornerRadius: 16)
        }
    }
}

private struct WorldPositionCard: View {
    let position: GameWorldPosition?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("게임 좌표", systemImage: "location.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
            if let position {
                Text("X \(position.x.formatted(.number.precision(.fractionLength(0...1))))")
                Text("Y \(position.y.formatted(.number.precision(.fractionLength(0...1))))")
                Text("Z \(position.z.formatted(.number.precision(.fractionLength(0...1))))")
                if let heading = position.headingDegrees {
                    Text("방향 \(Int(heading.rounded()))°")
                }
            } else {
                Text("실제 좌표 수신 대기")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
            Spacer(minLength: 0)
            Text("게임 월드 단위 · GPS 좌표가 아님")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(16)
        .dashboardCard(cornerRadius: 22)
    }
}

struct MusicScreen: View {
    @ObservedObject var player: LocalAudioPlayer
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("음악")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("가져온 오디오 파일을 실제 재생합니다")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Button { showingImporter = true } label: {
                    Label("파일 추가", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 24) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(Image(systemName: "waveform").font(.system(size: 64, weight: .light)).foregroundStyle(.white.opacity(0.95)))
                    .frame(width: 230, height: 230)
                    .shadow(color: .purple.opacity(0.22), radius: 24, y: 12)

                VStack(alignment: .leading, spacing: 16) {
                    Text(player.currentTrack?.title ?? "재생할 파일을 선택하세요")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .lineLimit(2)
                    Text(player.currentTrack == nil ? "이 앱은 iPad에서 선택한 파일만 재생합니다." : "iPad 음악 보관함 · 실제 재생 중")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))

                    Slider(value: Binding(get: { player.progress }, set: { player.seek(to: $0) }), in: 0...1)
                        .tint(.white)
                        .disabled(player.duration <= 0)
                    HStack {
                        Text(formatTime(player.currentTime))
                        Spacer()
                        Text(formatTime(player.duration))
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.60))

                    HStack(spacing: 28) {
                        Button(action: player.previous) { Image(systemName: "backward.end.fill") }
                        Button(action: player.togglePlayback) {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 22, weight: .bold))
                                .frame(width: 62, height: 62)
                                .background(Color.white.opacity(0.18), in: Circle())
                        }
                        .disabled(player.currentTrack == nil)
                        Button(action: player.next) { Image(systemName: "forward.end.fill") }
                    }
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: 440, alignment: .leading)
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, minHeight: 278, maxHeight: 300)
            .dashboardCard(cornerRadius: 28)

            if let importMessage = player.importMessage {
                Text(importMessage).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.68))
            }

            if player.tracks.isEmpty {
                ContentUnavailableView {
                    Label("음악 파일이 없습니다", systemImage: "music.note.list")
                } description: {
                    Text("‘파일 추가’를 눌러 iPad에 저장된 오디오 파일을 가져오세요.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(player.tracks) { track in
                        HStack(spacing: 12) {
                            Image(systemName: player.currentTrackID == track.id && player.isPlaying ? "waveform" : "music.note")
                                .foregroundStyle(.cyan)
                            Text(track.title)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Button { player.play(track) } label: { Image(systemName: "play.fill") }
                                .buttonStyle(.plain)
                            Button(role: .destructive) { player.remove(track) } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain)
                        }
                        .listRowBackground(Color.black.opacity(0.22))
                    }
                }
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.audio], allowsMultipleSelection: true) { result in
            if case .success(let urls) = result { player.importFiles(urls) }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite else { return "0:00" }
        let value = max(0, Int(seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

struct VirtualPhoneScreen: View {
    @ObservedObject var model: AppModel
    private var latestMessage: InboxMessage? { model.notifications.first }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: latestMessage == nil ? "phone.badge.waveform" : "phone.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(.green)
                    .frame(width: 108, height: 108)
                    .background(.green.opacity(0.15), in: Circle())
                Text(latestMessage == nil ? "운송센터 알림 대기" : "ETS2 이벤트 브리핑")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("실제 게임 이벤트를 음성으로 확인합니다. 이 기능은 전화망이나 실제 통화에 연결되지 않습니다.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if let latestMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Label(latestMessage.title, systemImage: latestMessage.symbol)
                        .font(.system(size: 16, weight: .semibold))
                    Text(latestMessage.detail)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                    HStack {
                        Button {
                            model.voice.speak("\(latestMessage.title). \(latestMessage.detail)", audioPlayer: model.audio)
                        } label: {
                            Label("응답해 듣기", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.green.opacity(0.70), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(latestMessage.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.54))
                    }
                }
                .padding(20)
                .dashboardCard(cornerRadius: 22)
            } else {
                ContentUnavailableView {
                    Label("수신된 게임 이벤트가 없습니다", systemImage: "phone.badge.waveform")
                } description: {
                    Text("배송 완료, 벌금, 톨게이트 이벤트가 실제로 도착하면 여기에 표시됩니다.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dashboardCard(cornerRadius: 22)
            }
        }
    }
}

struct MessagesScreen: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            VStack(alignment: .leading, spacing: 5) {
                Text("스마트 알림 센터")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("실제 ETS2 이벤트와 텔레메트리 경보")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
            }

            if model.notifications.isEmpty {
                ContentUnavailableView {
                    Label("아직 알림이 없습니다", systemImage: "bell.badge")
                } description: {
                    Text("벌금, 통행료, 배송 완료, 연료 부족, 과속, 차량 손상이 감지되면 여기에 나타납니다.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dashboardCard(cornerRadius: 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.notifications) { item in
                            HStack(spacing: 14) {
                                Image(systemName: item.symbol)
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(item.level == .urgent ? .red : (item.level == .warning ? .orange : .cyan))
                                    .frame(width: 46, height: 46)
                                    .background(Color.white.opacity(0.08), in: Circle())
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Text(item.title).font(.system(size: 14, weight: .semibold))
                                        Spacer()
                                        Text(item.date.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.53))
                                    }
                                    Text(item.detail)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.66))
                                        .lineLimit(2)
                                }
                            }
                            .padding(16)
                            Divider().overlay(Color.white.opacity(0.11)).padding(.leading, 76)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .dashboardCard(cornerRadius: 24)
            }
        }
    }
}

struct VoiceAssistantScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var assistant: VoiceAssistant

    init(model: AppModel) {
        self.model = model
        assistant = model.voice
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(alignment: .leading, spacing: 5) {
                Text("음성 비서")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                Text("눌러서 말하기 · 항상 듣지 않습니다")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                if assistant.isListening {
                    assistant.stopListening()
                } else {
                    assistant.startListening(audioPlayer: model.audio) { text in
                        let response = await model.handleVoiceCommand(text)
                        model.addVoiceResponse(response)
                        return response
                    }
                }
            } label: {
                VStack(spacing: 15) {
                    Image(systemName: assistant.isListening ? "stop.fill" : "mic.fill")
                        .font(.system(size: 38, weight: .semibold))
                        .frame(width: 112, height: 112)
                        .background(assistant.isListening ? .red.opacity(0.75) : .blue.opacity(0.65), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 1))
                    Text(assistant.isListening ? "듣는 중 · 누르면 종료" : "눌러서 말하기")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dashboardCard(cornerRadius: 26)

            if !assistant.transcript.isEmpty || !assistant.response.isEmpty || assistant.permissionMessage != nil {
                VStack(alignment: .leading, spacing: 10) {
                    if !assistant.transcript.isEmpty {
                        Text("인식한 말").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.58))
                        Text(assistant.transcript).font(.system(size: 14, weight: .medium))
                    }
                    if !assistant.response.isEmpty {
                        Text("응답").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.58))
                        Text(assistant.response).font(.system(size: 14, weight: .medium))
                    }
                    if let permissionMessage = assistant.permissionMessage {
                        Text(permissionMessage).font(.system(size: 12, weight: .medium)).foregroundStyle(.orange)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .dashboardCard(cornerRadius: 20)
            }

            Text("요청할 수 있는 정보: 속도, 연료, 목적지, 남은 거리, 알림. 조작: 음악, 경적, 라이트.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.57))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ControlsScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: BridgeConnectionManager

    init(model: AppModel) {
        self.model = model
        bridge = model.bridge
    }

    private let controls: [(String, String, String, Color)] = [
        ("엔진", "engine.toggle", "power", .green),
        ("라이트", "lights.toggle", "headlight.high.beam.fill", .yellow),
        ("경적", "horn", "speaker.wave.3.fill", .orange),
        ("주차 브레이크", "parkingBrake.toggle", "brakesignal", .red),
        ("와이퍼", "wipers.toggle", "drop.fill", .cyan),
        ("엔진 브레이크", "engineBrake.toggle", "arrow.down.to.line", .purple),
        ("기어 올리기", "gear.up", "plus", .blue),
        ("기어 내리기", "gear.down", "minus", .blue),
        ("크루즈", "cruise.toggle", "gauge.with.needle.fill", .mint),
        ("카메라", "camera.next", "camera.fill", .pink)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("트럭 제어")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("ETS2 창이 활성화된 동안 등록된 키만 전달")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Label(bridge.gameState.label, systemImage: bridge.gameState == .live ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(controls.indices, id: \.self) { index in
                    let item = controls[index]
                    Button { model.sendControl(item.1) } label: {
                        VStack(alignment: .leading, spacing: 11) {
                            Image(systemName: item.2)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(item.3)
                                .frame(width: 42, height: 42)
                                .background(item.3.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
                            Text(item.0).font(.system(size: 14, weight: .bold))
                            if item.1 == "parkingBrake.toggle", let state = bridge.snapshot?.parkingBrake {
                                Text(state ? "작동 중" : "해제됨")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.63))
                            } else {
                                Text("키 매핑은 Windows 설정")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .leading)
                        .padding(15)
                        .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 21))
                        .overlay(RoundedRectangle(cornerRadius: 21).stroke(Color.white.opacity(0.12), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .disabled(bridge.gameState != .live)
                    .opacity(bridge.gameState == .live ? 1 : 0.48)
                }
            }

            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill").foregroundStyle(.cyan)
                Text(bridge.lastCommandMessage ?? "조작 키는 WindowsBridge/BridgeServer/controls.json에서 게임의 키 설정에 맞춰 등록하세요.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.68))
                Spacer(minLength: 0)
            }
            .padding(13)
            .dashboardCard(cornerRadius: 16)
        }
    }
}
