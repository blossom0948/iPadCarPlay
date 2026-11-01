import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("운행 대시보드")
                            .font(.system(size: 29, weight: .bold, design: .rounded))
                        Text("ETS2 실제 텔레메트리")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                    Spacer()
                    Label(
                        bridge.isConnected ? bridge.gameState.label : bridge.status.label,
                        systemImage: bridge.isConnected && bridge.gameState == .live ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
                    )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.84))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.10), in: Capsule())
                }

                HStack(spacing: 16) {
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
                .frame(maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct NavigationDataCard: View {
    let snapshot: TelemetrySnapshot?
    let gameState: GameConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("ETS2 내비게이션 정보", systemImage: "location.north.line.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 0.60, green: 0.94, blue: 0.82))
                Spacer()
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.62))
            }

            if let snapshot {
                VStack(alignment: .leading, spacing: 7) {
                    Text(snapshot.destinationCity ?? "목적지 정보 없음")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(snapshot.destinationCompany ?? snapshot.cargo ?? "게임이 제공하는 목적지 정보")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.68))
                }
                Spacer(minLength: 2)
                HStack(spacing: 0) {
                    NavigationMetric(title: "남은 거리", value: snapshot.navigationDistanceKm.map { "\($0.formatted(.number.precision(.fractionLength(0...1)))) km" } ?? "—")
                    Spacer()
                    NavigationMetric(title: "예상 시간", value: snapshot.navigationEtaSeconds.map(formatDuration) ?? "—")
                    Spacer()
                    NavigationMetric(title: "제한 속도", value: snapshot.speedLimitKph.map { "\(Int($0.rounded())) km/h" } ?? "—")
                }
                Divider().overlay(Color.white.opacity(0.14))
                HStack(spacing: 9) {
                    Image(systemName: gameState == .live ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(gameState == .live ? .green : .orange)
                    Text(gameState.label)
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("SCS SDK 데이터")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                }
            } else {
                Spacer()
                ContentUnavailableView {
                    Label("실제 주행 데이터를 기다리는 중", systemImage: "antenna.radiowaves.left.and.right")
                } description: {
                    Text("Windows 브리지와 ETS2 텔레메트리 플러그인을 연결하면 게임에서 받은 값이 표시됩니다.")
                }
                .foregroundStyle(.white)
                Spacer()
            }

            Text("ETS2는 도로 경로선을 제공하지 않으므로 이 화면은 실제 거리·ETA·제한속도만 표시합니다.")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Color(red: 0.03, green: 0.13, blue: 0.16).opacity(0.88), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28, style: .continuous).stroke(Color.white.opacity(0.13), lineWidth: 1))
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("트럭 계기판", systemImage: "steeringwheel")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(snapshot?.paused == true ? "일시정지" : (snapshot?.gameActive == true ? "주행 중" : "대기"))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.64))
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(speedText)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(speedUnit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.66))
                Spacer()
                Text("기어 \(snapshot?.gear.map(String.init) ?? "—")")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            HStack(spacing: 12) {
                MiniGauge(title: "연료", value: snapshot?.fuelPercent.map { "\(Int($0.rounded()))%" } ?? "—", symbol: "fuelpump.fill")
                MiniGauge(title: "RPM", value: snapshot?.engineRpm.map { "\(Int($0.rounded()))" } ?? "—", symbol: "gauge.with.needle.fill")
            }
            if let capacity = snapshot?.fuelCapacityLiters, let fuel = snapshot?.fuelLiters {
                Text("연료 \(fuel.formatted(.number.precision(.fractionLength(0...1)))) / \(capacity.formatted(.number.precision(.fractionLength(0...1)))) L")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard(cornerRadius: 24)
    }

    private var speedText: String {
        guard let snapshot else { return "—" }
        let speed = speedUnit == "mph" ? snapshot.speedMph : snapshot.speedKph
        return speed.map { String(Int(abs($0).rounded())) } ?? "—"
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("음악", systemImage: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text(player.isPlaying ? "재생 중" : "실제 보관함")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
            }
            HStack(spacing: 13) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(LinearGradient(colors: [.purple, .pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 58, height: 58)
                    .overlay(Image(systemName: "waveform").font(.system(size: 23)).foregroundStyle(.white))
                VStack(alignment: .leading, spacing: 5) {
                    Text(player.currentTrack?.title ?? "음악 파일을 추가하세요")
                        .font(.system(size: 14, weight: .bold))
                        .lineLimit(1)
                    Text(player.currentTrack == nil ? "가져온 파일만 표시됩니다" : "iPad 음악 보관함")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 22) {
                Button(action: player.previous) { Image(systemName: "backward.end.fill") }
                Button(action: player.togglePlayback) {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.17), in: Circle())
                }
                .disabled(player.currentTrack == nil)
                Button(action: player.next) { Image(systemName: "forward.end.fill") }
                Spacer()
                Text(player.currentTrack == nil ? "재생 정보 없음" : "실제 재생")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCard(cornerRadius: 24)
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
