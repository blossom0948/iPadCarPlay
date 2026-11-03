import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import MusicKit

struct DashboardScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: BridgeConnectionManager
    let speedUnit: String

    init(model: AppModel, speedUnit: String) {
        self.model = model
        bridge = model.bridge
        self.speedUnit = speedUnit
    }

    private var snapshot: TelemetrySnapshot? { bridge.snapshot }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.height < 500 {
                HStack(spacing: 12) {
                    NavigationDataCard(snapshot: snapshot, gameState: bridge.gameState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    MusicMiniCard(player: model.audio)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    TruckTelemetryCard(snapshot: snapshot, speedUnit: speedUnit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else if geometry.size.width < 720 {
                ScrollView(.vertical) {
                    VStack(spacing: 12) {
                        NavigationDataCard(snapshot: snapshot, gameState: bridge.gameState)
                            .frame(minHeight: max(250, geometry.size.height * 0.43))
                        VStack(spacing: 12) {
                            MusicMiniCard(player: model.audio)
                                .frame(minHeight: 180)
                            TruckTelemetryCard(snapshot: snapshot, speedUnit: speedUnit)
                                .frame(minHeight: 210)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .scrollIndicators(.hidden)
            } else {
                HStack(spacing: 13) {
                    NavigationDataCard(snapshot: snapshot, gameState: bridge.gameState)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    VStack(spacing: 16) {
                        MusicMiniCard(player: model.audio)
                            .frame(maxHeight: .infinity)
                        TruckTelemetryCard(snapshot: snapshot, speedUnit: speedUnit)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: min(max(geometry.size.width * 0.34, 290), 360))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct NavigationDataCard: View {
    let snapshot: TelemetrySnapshot?
    let gameState: GameConnectionState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("내비게이션", systemImage: "location.north.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                Spacer()
                HStack(spacing: 7) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(gameState == .live ? Color.green : Color.orange)
                        .symbolEffect(.pulse, options: .repeating, isActive: gameState == .live && !reduceMotion)
                    Text(gameState.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    if #available(iOS 26.0, *) {
                        Color.clear.glassEffect(.regular, in: Capsule())
                    } else {
                        Capsule().fill(Color.white.opacity(0.10))
                    }
                }
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }

            if let snapshot {
                VStack(alignment: .leading, spacing: 8) {
                    Text("목적지")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(snapshot.destinationCity ?? "목적지 정보 없음")
                        .font(.system(size: 31, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(snapshot.destinationCompany ?? snapshot.cargo ?? "게임에서 받은 운행 정보")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
                .padding(.top, 34)

                Spacer(minLength: 16)

                VStack(alignment: .leading, spacing: 5) {
                    Text("남은 거리")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(snapshot.navigationDistanceKm.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) km" } ?? "—")
                        .font(.system(size: 43, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(reduceMotion ? .identity : .numericText())
                }

                Spacer(minLength: 22)

                HStack(spacing: 0) {
                    NavigationMetric(title: "예상 시간", value: snapshot.navigationEtaSeconds.map(formatDuration) ?? "—")
                    Rectangle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 1, height: 43)
                        .padding(.horizontal, 22)
                    NavigationMetric(title: "속도 제한", value: snapshot.speedLimitKph.map { "\(Int($0.rounded())) km/h" } ?? "—")
                    Spacer(minLength: 0)
                }
            } else {
                Spacer(minLength: 18)
                HStack(spacing: 19) {
                    Image(systemName: "location.north.circle.fill")
                        .font(.system(size: 45, weight: .regular))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 0.28, green: 0.70, blue: 1.00))
                    VStack(alignment: .leading, spacing: 7) {
                        Text("ETS2 연결 대기 중")
                            .font(.system(size: 23, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Windows 브리지와 게임을 연결하면 경로 정보가 여기에 표시됩니다.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.66))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 18)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
    }

    private func formatDuration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "—" }
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 { return "\(totalMinutes / 60)시간 \(totalMinutes % 60)분" }
        return "\(totalMinutes)분"
    }
}

private struct NavigationMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
            Text(value)
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
    }
}

struct TruckTelemetryCard: View {
    let snapshot: TelemetrySnapshot?
    let speedUnit: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Label("차량", systemImage: "steeringwheel")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(snapshot?.paused == true ? "일시정지" : (snapshot?.gameActive == true ? "주행 중" : "대기"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(speedText)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isOverspeed ? Color.red : Color.white)
                    .contentTransition(.numericText())
                Text(speedUnit)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("기어 \(snapshot?.gear.map(String.init) ?? "—")")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(snapshot?.engineRpm.map { "\(Int($0.rounded())) RPM" } ?? "RPM —")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "fuelpump.fill")
                        .foregroundStyle(fuelColor)
                    Text("연료")
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    Text(fuelLabel)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    Text(fuelCapacityLabel)
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                }
                .font(.system(size: 11, weight: .semibold))

                ProgressView(value: snapshot?.fuelPercent.map { $0 / 100 } ?? 0)
                    .tint(fuelColor)
                    .scaleEffect(x: 1, y: 1.35, anchor: .center)
                    .opacity(snapshot?.fuelPercent == nil ? 0.38 : 1)
            }

            HStack(spacing: 8) {
                VehicleStatusTile(
                    title: "방향지시등",
                    detail: indicatorLabel,
                    symbol: indicatorSymbol,
                    active: indicatorActive,
                    tint: .orange,
                    animate: indicatorActive && !reduceMotion
                )
                VehicleStatusTile(
                    title: "와이퍼",
                    detail: snapshot?.wipers.map { $0 ? "켜짐" : "꺼짐" } ?? "정보 없음",
                    symbol: "drop.fill",
                    active: snapshot?.wipers == true,
                    tint: .cyan
                )
                VehicleStatusTile(
                    title: "전조등",
                    detail: lightLabel,
                    symbol: "headlight.high.beam.fill",
                    active: lightActive,
                    tint: .yellow
                )
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard(cornerRadius: 24)
    }

    private var speedText: String {
        guard let snapshot else { return "—" }
        let speed = speedUnit == "mph" ? snapshot.speedMph : snapshot.speedKph
        return speed.map { String(Int(abs($0).rounded())) } ?? "—"
    }

    private var isOverspeed: Bool {
        guard let snapshot,
              let rawSpeed = speedUnit == "mph" ? snapshot.speedMph : snapshot.speedKph,
              let rawLimit = speedUnit == "mph" ? snapshot.speedLimitKph.map({ $0 / 1.609344 }) : snapshot.speedLimitKph,
              rawLimit > 0 else { return false }
        return abs(rawSpeed) > rawLimit + 1
    }

    private var fuelLabel: String {
        snapshot?.fuelPercent.map { "\(Int($0.rounded()))%" } ?? "—"
    }

    private var fuelCapacityLabel: String {
        guard let fuel = snapshot?.fuelLiters, let capacity = snapshot?.fuelCapacityLiters else { return "" }
        return "\(fuel.formatted(.number.precision(.fractionLength(0...1)))) / \(capacity.formatted(.number.precision(.fractionLength(0...1)))) L"
    }

    private var fuelColor: Color {
        guard let percent = snapshot?.fuelPercent else { return .white.opacity(0.5) }
        return percent < 12 ? .red : (percent < 25 ? .orange : .green)
    }

    private var indicatorActive: Bool {
        snapshot?.hazardWarning == true || snapshot?.leftIndicator == true || snapshot?.rightIndicator == true
    }

    private var indicatorSymbol: String {
        if snapshot?.hazardWarning == true || (snapshot?.leftIndicator == true && snapshot?.rightIndicator == true) {
            return "exclamationmark.triangle.fill"
        }
        if snapshot?.leftIndicator == true { return "arrow.left" }
        if snapshot?.rightIndicator == true { return "arrow.right" }
        return "arrow.left.arrow.right"
    }

    private var indicatorLabel: String {
        if snapshot?.hazardWarning == true || (snapshot?.leftIndicator == true && snapshot?.rightIndicator == true) { return "비상등" }
        if snapshot?.leftIndicator == true { return "좌회전" }
        if snapshot?.rightIndicator == true { return "우회전" }
        if snapshot?.leftIndicator == nil && snapshot?.rightIndicator == nil && snapshot?.hazardWarning == nil { return "정보 없음" }
        return "꺼짐"
    }

    private var lightActive: Bool {
        snapshot?.parkingLights == true || snapshot?.lowBeam == true || snapshot?.highBeam == true
    }

    private var lightLabel: String {
        if snapshot?.highBeam == true { return "상향등" }
        if snapshot?.lowBeam == true { return "하향등" }
        if snapshot?.parkingLights == true { return "미등" }
        if snapshot?.parkingLights == nil && snapshot?.lowBeam == nil && snapshot?.highBeam == nil { return "정보 없음" }
        return "꺼짐"
    }
}

private struct VehicleStatusTile: View {
    let title: String
    let detail: String
    let symbol: String
    let active: Bool
    let tint: Color
    var animate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(active ? tint : Color.white.opacity(0.52))
                .symbolEffect(.pulse, options: .repeating, isActive: animate)
            Text(title)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white.opacity(active ? 0.96 : 0.74))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.white.opacity(active ? 0.09 : 0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(active ? tint.opacity(0.27) : Color.white.opacity(0.06), lineWidth: 1))
    }
}

private struct FuelRouteInsight: View {
    let snapshot: TelemetrySnapshot?
    @AppStorage("alerts.routeFuel.margin") private var cautionMarginKm = 30.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rangeKm: Double? { snapshot?.fuelRangeKm }
    private var destinationKm: Double? { snapshot?.navigationDistanceKm }
    private var marginKm: Double? {
        guard let rangeKm, let destinationKm else { return nil }
        return rangeKm - destinationKm
    }
    private var accent: Color {
        guard let marginKm else { return .white.opacity(0.72) }
        if marginKm < 0 { return .red }
        return marginKm <= cautionMarginKm ? .orange : .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "fuelpump.fill")
                    .foregroundStyle(accent)
                Text("목적지 연료 여유")
                    .foregroundStyle(.white.opacity(0.72))
                Spacer(minLength: 4)
                Text(statusText)
                    .fontWeight(.bold)
                    .foregroundStyle(accent)
                    .contentTransition(reduceMotion ? .identity : .numericText())
            }
            .font(.system(size: 11, weight: .medium))

            GeometryReader { geometry in
                let progress = min(max((destinationKm ?? 0) / max(rangeKm ?? 1, 1), 0), 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.13))
                    Capsule()
                        .fill(accent.gradient)
                        .frame(width: max(5, geometry.size.width * progress))
                }
            }
            .frame(height: 5)

            Text(detailText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        guard let marginKm else { return "대기" }
        if marginKm < 0 { return "주유 필요" }
        return "+\(Int(marginKm.rounded())) km"
    }

    private var detailText: String {
        guard let rangeKm, let destinationKm else { return "ETS2 주행 데이터 연결 후 표시됩니다." }
        return "주행 가능 \(Int(rangeKm.rounded())) km · 목적지까지 \(Int(destinationKm.rounded())) km"
    }
}

private struct DriveCountdownInsight: View {
    let title: String
    let minutes: Int?
    let emptyText: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(reduceMotion ? .identity : .numericText())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var value: String {
        guard let minutes else { return emptyText }
        if title == "배송 마감", minutes < 0 { return "기한 초과 \(formatGameMinutes(-minutes))" }
        if minutes == 0 { return title == "휴식까지" ? "지금 휴식" : "마감 시각" }
        return formatGameMinutes(minutes)
    }

    private func formatGameMinutes(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)분" }
        return remainder == 0 ? "\(hours)시간" : "\(hours)시간 \(remainder)분"
    }
}

private struct MiniGauge: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.59))
                .lineLimit(1)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 15))
    }
}

private struct MusicMiniCard: View {
    @ObservedObject var player: LocalAudioPlayer
    @State private var appleQueue = ApplicationMusicPlayer.shared.queue
    @State private var appleState = ApplicationMusicPlayer.shared.state
    @StateObject private var systemMusic = SystemMusicNowPlaying()
    @AppStorage("showSystemMusic") private var showSystemMusic = true
    private let applePlayer = ApplicationMusicPlayer.shared

    private enum Source { case applicationMusic, systemMusic, localFile, none }

    private var source: Source {
        if showSystemMusic && systemMusic.isPlaying { return .systemMusic }
        if appleQueue.currentEntry != nil { return .applicationMusic }
        if player.currentTrack != nil { return .localFile }
        if showSystemMusic && systemMusic.title != nil { return .systemMusic }
        return .none
    }

    private var isAppleMusicActive: Bool { source == .applicationMusic }
    private var isPlaying: Bool {
        switch source {
        case .applicationMusic: appleState.playbackStatus == .playing
        case .systemMusic: systemMusic.isPlaying
        case .localFile: player.isPlaying
        case .none: false
        }
    }
    private var hasTrack: Bool { source != .none }

    private var trackTitle: String {
        switch source {
        case .applicationMusic: appleQueue.currentEntry?.title ?? "Apple Music"
        case .systemMusic: systemMusic.title ?? "Apple Music 앱"
        case .localFile: player.currentTrack?.title ?? "가져온 오디오 파일"
        case .none: "음악을 선택하세요"
        }
    }

    private var trackArtist: String {
        switch source {
        case .applicationMusic: appleQueue.currentEntry?.subtitle ?? "Apple Music"
        case .systemMusic: systemTrackSubtitle
        case .localFile: "가져온 오디오 파일"
        case .none: showSystemMusic && !systemMusic.isAuthorized ? "미디어 접근을 허용해 주세요" : "Apple Music 또는 파일을 선택하세요"
        }
    }

    private var systemTrackSubtitle: String {
        let details = [systemMusic.artist, systemMusic.album]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return details.isEmpty ? "Apple Music 앱" : details.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("지금 재생 중", systemImage: "music.note")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(isPlaying ? "재생 중" : (hasTrack ? "일시 정지" : "선택 없음"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
            }
            HStack(spacing: 13) {
                Group {
                    if source == .systemMusic, let artwork = systemMusic.artwork {
                        Image(uiImage: artwork)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    } else if source == .applicationMusic, let artwork = appleQueue.currentEntry?.artwork {
                        ArtworkImage(artwork, width: 58, height: 58)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Image(systemName: "waveform").font(.system(size: 23)).foregroundStyle(.white))
                    }
                }
                .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text(trackTitle)
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text(trackArtist)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 22) {
                Button {
                    switch source {
                    case .applicationMusic: Task { try? await applePlayer.skipToPreviousEntry() }
                    case .systemMusic: systemMusic.skipToPrevious()
                    case .localFile: player.previous()
                    case .none: break
                    }
                } label: { Image(systemName: "backward.end.fill") }
                Button {
                    if source == .systemMusic {
                        systemMusic.togglePlayback()
                    } else if isAppleMusicActive {
                        if isPlaying { applePlayer.pause() }
                        else { Task { try? await applePlayer.play() } }
                    } else {
                        player.togglePlayback()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.17), in: Circle())
                }
                .disabled(!hasTrack)
                Button {
                    switch source {
                    case .applicationMusic: Task { try? await applePlayer.skipToNextEntry() }
                    case .systemMusic: systemMusic.skipToNext()
                    case .localFile: player.next()
                    case .none: break
                    }
                } label: { Image(systemName: "forward.end.fill") }
                Spacer()
                Text(hasTrack ? (source == .systemMusic ? "Music 앱" : (isAppleMusicActive ? "앱 내 Apple Music" : "파일 재생")) : "재생 정보 없음")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard(cornerRadius: 24)
        .task(id: showSystemMusic) {
            if showSystemMusic { await systemMusic.start() }
            else { systemMusic.stop() }
        }
        .onDisappear { systemMusic.stop() }
    }
}

struct StatsScreen: View {
    @ObservedObject var model: AppModel
    let speedUnit: String
    @Query(sort: \TripRecord.startedAt, order: .reverse) private var trips: [TripRecord]
    @State private var showingExporter = false
    @State private var exportDocument = TripCSVDocument(records: [])

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("운행 통계")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("SCS 텔레메트리로 기록한 운행")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Menu {
                    Button("현재 운행 기록 마감", systemImage: "stop.circle") { model.finishTrip() }
                        .disabled(!model.hasActiveTrip)
                    Button("CSV로 내보내기", systemImage: "square.and.arrow.up") {
                        exportDocument = TripCSVDocument(records: trips)
                        showingExporter = true
                    }
                    .disabled(trips.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.system(size: 25))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }

            HStack(spacing: 14) {
                StatisticTile(title: "운행 횟수", value: "\(trips.count)", detail: "저장된 세션")
                StatisticTile(title: "총 거리", value: "\(trips.reduce(0) { $0 + $1.distanceKm }.formatted(.number.precision(.fractionLength(0...1)))) km", detail: "오도미터 차이")
                StatisticTile(title: "연료 사용", value: "\(trips.reduce(0) { $0 + $1.fuelUsedLiters }.formatted(.number.precision(.fractionLength(0...1)))) L", detail: "실제 연료 감소량")
            }

            if trips.isEmpty {
                ContentUnavailableView {
                    Label("저장된 운행이 없습니다", systemImage: "chart.bar.xaxis")
                } description: {
                    Text("ETS2를 연결해 주행하면 실제 운행 세션이 여기에 쌓입니다.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .dashboardCard(cornerRadius: 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(trips) { trip in
                            TripRow(trip: trip, speedUnit: speedUnit)
                        }
                    }
                    .padding(2)
                }
                .scrollIndicators(.hidden)
            }
        }
        .fileExporter(isPresented: $showingExporter, document: exportDocument, contentType: .commaSeparatedText, defaultFilename: "ETS2-Trips") { _ in }
    }
}

private struct StatisticTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.59))
            Text(value).font(.system(size: 21, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
            Text(detail).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.50))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .dashboardCard(cornerRadius: 20)
    }
}

private struct TripRow: View {
    let trip: TripRecord
    let speedUnit: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: trip.delivered ? "checkmark.seal.fill" : "truck.box.fill")
                .font(.system(size: 20))
                .foregroundStyle(trip.delivered ? .green : .cyan)
                .frame(width: 46, height: 46)
                .background(Color.white.opacity(0.08), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(trip.destination ?? trip.cargo ?? "운행 세션")
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(trip.startedAt.formatted(date: .abbreviated, time: .shortened) + (trip.endedAt.map { " · 종료 \($0.formatted(date: .omitted, time: .shortened))" } ?? " · 진행 중"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.54))
            }
            Spacer(minLength: 6)
            VStack(alignment: .trailing, spacing: 5) {
                Text("\(trip.distanceKm.formatted(.number.precision(.fractionLength(0...1)))) km")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                let avgSpeed = speedUnit == "mph" ? trip.averageSpeedKph / 1.609344 : trip.averageSpeedKph
                Text("평균 \(Int(avgSpeed.rounded())) \(speedUnit)")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .padding(14)
        .dashboardCard(cornerRadius: 18)
    }
}

struct TripCSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data

    init(records: [TripRecord]) {
        let rows = ["started_at,ended_at,cargo,destination,distance_km,fuel_liters,average_speed_kph,maximum_speed_kph,moving_seconds,fines,tolls,revenue,delivered"] + records.map { trip in
            [trip.startedAt.ISO8601Format(), trip.endedAt?.ISO8601Format() ?? "", trip.cargo ?? "", trip.destination ?? "",
             String(trip.distanceKm), String(trip.fuelUsedLiters), String(trip.averageSpeedKph), String(trip.maximumSpeedKph),
             String(trip.movingSeconds), String(trip.finesAmount), String(trip.tollsAmount), String(trip.revenueAmount), String(trip.delivered)]
                .map(Self.escapeCSV).joined(separator: ",")
        }
        data = Data(rows.joined(separator: "\n").utf8)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }

    private static func escapeCSV(_ value: String) -> String {
        "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
