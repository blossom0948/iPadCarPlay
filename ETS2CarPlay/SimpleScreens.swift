import SwiftUI
import UniformTypeIdentifiers
import MusicKit
import MessageUI
import UIKit

struct AppsScreen: View {
    @ObservedObject var layoutStore: AppLayoutStore
    let onSelect: (AppSection) -> Void
    var preferredColumns = 6
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPage = 0
    @State private var iconsVisible = false

    var body: some View {
        GeometryReader { geometry in
            let columnCount = geometry.size.width < 560 ? 3 : (geometry.size.width < 820 ? 4 : preferredColumns)
            let pageSize = columnCount * 2
            let iconSize = min(150, geometry.size.width / CGFloat(columnCount) * 0.55, geometry.size.height * 0.23)
            let rowWidth = geometry.size.width * 0.97
            let rowCenterX = geometry.size.width * 0.495
            let sections = layoutStore.visibleSections
            let pages = stride(from: 0, to: sections.count, by: pageSize).map { start in
                Array(sections[start..<min(start + pageSize, sections.count)])
            }

            Group {
                if sections.isEmpty {
                    ContentUnavailableView {
                        Label("표시할 앱이 없습니다", systemImage: "square.grid.2x2")
                    } description: {
                        Text("설정의 앱 정리에서 앱 아이콘을 다시 표시하세요.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TabView(selection: $selectedPage) {
                        ForEach(pages.indices, id: \.self) { pageIndex in
                            let page = pages[pageIndex]
                            ZStack {
                                if !page.prefix(columnCount).isEmpty {
                                    appGridRow(Array(page.prefix(columnCount)), iconSize: iconSize, columnCount: columnCount)
                                        .frame(width: rowWidth)
                                        .position(x: rowCenterX, y: geometry.size.height * 0.297)
                                }

                                let secondRow = Array(page.dropFirst(columnCount))
                                if !secondRow.isEmpty {
                                    appGridRow(secondRow, iconSize: iconSize, columnCount: columnCount)
                                        .frame(width: rowWidth)
                                        .position(x: rowCenterX, y: geometry.size.height * 0.687)
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .contentShape(Rectangle())
                            .tag(pageIndex)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88),
                        value: selectedPage
                    )
                    .overlay(alignment: .bottom) {
                        if pages.count > 1 {
                            HStack(spacing: max(7, geometry.size.width * 0.012)) {
                                ForEach(pages.indices, id: \.self) { pageIndex in
                                    Capsule()
                                        .fill(pageIndex == selectedPage ? Color.white : Color.white.opacity(0.38))
                                        .frame(
                                            width: pageIndex == selectedPage ? max(20, iconSize * 0.19) : max(7, iconSize * 0.07),
                                            height: max(5, iconSize * 0.06)
                                        )
                                        .animation(
                                            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.78),
                                            value: selectedPage
                                        )
                                }
                            }
                            .padding(.bottom, geometry.size.height * 0.055)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("앱 페이지 \(selectedPage + 1), 총 \(pages.count)페이지")
                        } else {
                            Capsule()
                                .fill(Color.white.opacity(0.72))
                                .frame(width: max(20, iconSize * 0.19), height: max(5, iconSize * 0.06))
                                .padding(.bottom, geometry.size.height * 0.055)
                                .accessibilityLabel("앱 페이지 1")
                        }
                    }
                    .onChange(of: sections) { _, _ in
                        selectedPage = 0
                    }
                    .onAppear { iconsVisible = true }
                    .onDisappear { iconsVisible = false }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func appGridRow(_ sections: [AppSection], iconSize: CGFloat, columnCount: Int) -> some View {
        let leadingEmptySlots = max(0, (columnCount - sections.count) / 2)
        let trailingEmptySlots = max(0, columnCount - sections.count - leadingEmptySlots)

        return HStack(spacing: 0) {
            ForEach(0..<leadingEmptySlots, id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }

            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                Button { onSelect(section) } label: {
                    VStack(spacing: max(5, iconSize * 0.085)) {
                        AppIconTile(section: section)
                            .frame(width: iconSize, height: iconSize)

                        Text(section.launcherTitle)
                            .font(.system(size: max(14, iconSize * 0.18), weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .padding(.horizontal, max(8, iconSize * 0.085))
                            .padding(.vertical, max(3, iconSize * 0.035))
                            .background(Color.black.opacity(0.50), in: RoundedRectangle(cornerRadius: max(4, iconSize * 0.04), style: .continuous))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .opacity(iconsVisible ? 1 : 0)
                    .scaleEffect(iconsVisible || reduceMotion ? 1 : 0.90)
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.76).delay(Double(index) * 0.035),
                        value: iconsVisible
                    )
                }
                .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.93))
            }

            ForEach(0..<trailingEmptySlots, id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
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

            GeometryReader { geometry in
                if geometry.size.width < 720 {
                    ScrollView(.vertical) {
                        VStack(spacing: 12) {
                            NavigationDataCard(snapshot: bridge.snapshot, gameState: bridge.gameState)
                                .frame(minHeight: max(250, geometry.size.height * 0.48))
                            HStack(spacing: 12) {
                                TruckTelemetryCard(snapshot: bridge.snapshot, speedUnit: speedUnit)
                                    .frame(minHeight: 210)
                                WorldPositionCard(position: bridge.snapshot?.worldPosition)
                                    .frame(minHeight: 210)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                } else {
                    HStack(spacing: 15) {
                        NavigationDataCard(snapshot: bridge.snapshot, gameState: bridge.gameState)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        VStack(spacing: 14) {
                            TruckTelemetryCard(snapshot: bridge.snapshot, speedUnit: speedUnit)
                                .frame(maxHeight: .infinity)
                            WorldPositionCard(position: bridge.snapshot?.worldPosition)
                                .frame(maxHeight: .infinity)
                        }
                        .frame(width: min(300, geometry.size.width * 0.32))
                    }
                }
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
    @State private var source = "appleMusic"

    var body: some View {
        VStack(spacing: 14) {
            Picker("음악 소스", selection: $source) {
                Text("Apple Music").tag("appleMusic")
                Text("가져온 파일").tag("localFiles")
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 420)

            if source == "appleMusic" {
                AppleMusicCatalogView()
            } else {
                LocalMusicLibraryView(player: player)
            }
        }
    }
}

private struct AppleMusicCatalogView: View {
    @State private var authorization = MusicAuthorization.currentStatus
    @State private var subscription: MusicSubscription?
    @State private var searchTerm = ""
    @State private var songs: [Song] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var queue = ApplicationMusicPlayer.shared.queue
    @State private var playbackState = ApplicationMusicPlayer.shared.state
    @State private var showingSubscriptionOffer = false
    private let player = ApplicationMusicPlayer.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Apple Music")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("카탈로그 검색 및 앱 안에서 재생")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Label(subscription?.canPlayCatalogContent == true ? "구독 사용 가능" : "구독 확인 필요", systemImage: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.10), in: Capsule())
            }

            if authorization == .authorized {
                nowPlayingCard

                HStack(spacing: 10) {
                    TextField("곡, 아티스트 또는 앨범 검색", text: $searchTerm)
                        .textFieldStyle(.roundedBorder)
                        .submitLabel(.search)
                        .onSubmit { Task { await search() } }
                    Button {
                        Task { await search() }
                    } label: {
                        if isSearching { ProgressView().tint(.white) }
                        else { Label("검색", systemImage: "magnifyingglass") }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSearching || searchTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.orange)
                }

                if songs.isEmpty {
                    ContentUnavailableView {
                        Label("Apple Music에서 곡 검색", systemImage: "music.note.list")
                    } description: {
                        Text("검색 결과를 누르면 Apple Music 플레이어가 재생을 시작합니다.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(songs) { song in
                        HStack(spacing: 12) {
                            if let artwork = song.artwork {
                                ArtworkImage(artwork, width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 9))
                            } else {
                                Image(systemName: "music.note")
                                    .frame(width: 48, height: 48)
                                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(song.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                Text(song.artistName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.62)).lineLimit(1)
                            }
                            Spacer()
                            Button {
                                Task { await play(song) }
                            } label: {
                                Image(systemName: "play.fill").frame(width: 36, height: 36)
                            }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("\(song.title) 재생")
                        }
                        .listRowBackground(Color.black.opacity(0.22))
                    }
                    .scrollContentBackground(.hidden)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }
            } else {
                ContentUnavailableView {
                    Label("Apple Music 권한 필요", systemImage: "music.note.house")
                } description: {
                    Text("음악 접근을 허용하면 카탈로그 검색과 재생을 사용할 수 있습니다. 전체 카탈로그 재생에는 Apple Music 구독이 필요합니다.")
                } actions: {
                    Button("Apple Music 접근 허용") {
                        Task { await requestAuthorization() }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: authorization == .authorized) {
            guard authorization == .authorized else { return }
            subscription = try? await MusicSubscription.current
            for await updatedSubscription in MusicSubscription.subscriptionUpdates {
                if Task.isCancelled { return }
                subscription = updatedSubscription
            }
        }
        .modifier(MusicSubscriptionOfferModifier(isPresented: $showingSubscriptionOffer))
        .tint(.blue)
    }

    private var nowPlayingCard: some View {
        HStack(spacing: 16) {
            if let artwork = queue.currentEntry?.artwork {
                ArtworkImage(artwork, width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                RoundedRectangle(cornerRadius: 14)
                    .fill(LinearGradient(colors: [.blue, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 76, height: 76)
                    .overlay(Image(systemName: "waveform").font(.system(size: 26)).foregroundStyle(.white))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(queue.currentEntry?.title ?? "재생 중인 곡 없음")
                    .font(.system(size: 14, weight: .bold))
                    .lineLimit(1)
                Text(queue.currentEntry?.subtitle ?? "검색 결과에서 곡을 선택하세요")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                Text(playbackState.playbackStatus == .playing ? "재생 중" : "대기")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.cyan)
            }
            Spacer(minLength: 0)
            Button {
                if playbackState.playbackStatus == .playing {
                    player.pause()
                } else {
                    Task { await resumePlayback() }
                }
            } label: {
                Image(systemName: playbackState.playbackStatus == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(queue.currentEntry == nil)
            Button {
                Task { try? await player.skipToNextEntry() }
            } label: {
                Image(systemName: "forward.end.fill")
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(queue.currentEntry == nil)
        }
        .padding(15)
        .dashboardCard(cornerRadius: 20)
    }

    private func requestAuthorization() async {
        authorization = await MusicAuthorization.request()
        if authorization != .authorized { errorMessage = "설정에서 Apple Music 접근을 허용해야 합니다." }
    }

    private func search() async {
        guard authorization == .authorized else { return }
        let term = searchTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            var request = MusicCatalogSearchRequest(term: term, types: [Song.self])
            request.limit = 25
            let response = try await request.response()
            songs = Array(response.songs)
            if songs.isEmpty { errorMessage = "검색 결과가 없습니다." }
        } catch {
            errorMessage = "음악 카탈로그를 검색하지 못했습니다. 권한과 네트워크를 확인해 주세요."
        }
    }

    private func play(_ song: Song) async {
        guard subscription?.canPlayCatalogContent == true else {
            showingSubscriptionOffer = subscription?.canBecomeSubscriber == true
            errorMessage = "카탈로그 재생에는 Apple Music 구독이 필요합니다."
            return
        }
        do {
            player.queue = ApplicationMusicPlayer.Queue(for: [song], startingAt: song)
            try await player.play()
            queue = player.queue
            playbackState = player.state
            errorMessage = nil
        } catch {
            errorMessage = "이 곡을 재생하지 못했습니다. 계정 구독 상태나 곡 이용 가능 여부를 확인해 주세요."
        }
    }

    private func resumePlayback() async {
        do {
            try await player.play()
        } catch {
            errorMessage = "재생을 시작하지 못했습니다."
        }
    }
}

private struct MusicSubscriptionOfferModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.musicSubscriptionOffer(
                isPresented: $isPresented,
                options: MusicSubscriptionOffer.Options(messageIdentifier: .playMusic)
            )
        } else {
            content.musicSubscriptionOffer(isPresented: $isPresented, options: .default)
        }
    }
}

private struct LocalMusicLibraryView: View {
    @ObservedObject var player: LocalAudioPlayer
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("가져온 음악 파일")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("iPad에 저장한 오디오를 앱 안에서 재생")
                        .font(.system(size: 13, weight: .medium))
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
                    Text(player.currentTrack == nil ? "선택한 파일을 이 앱에 보관합니다." : "iPad의 오디오 파일을 재생 중")
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
                            Text(track.title).font(.system(size: 13, weight: .semibold))
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
    @Environment(\.openURL) private var openURL
    @State private var destination = ""
    @State private var showingMessageComposer = false
    @State private var phoneStatus: String?
    private var latestMessage: InboxMessage? { model.notifications.first }

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Image(systemName: latestMessage == nil ? "phone.badge.waveform" : "phone.fill")
                    .font(.system(size: 50, weight: .light))
                    .foregroundStyle(.green)
                    .frame(width: 108, height: 108)
                    .background(.green.opacity(0.15), in: Circle())
                Text("FaceTime 오디오 · 메시지")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("iPad에서 사용할 수 있는 FaceTime과 메시지 작성 기능을 연결합니다.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                TextField("전화번호 또는 FaceTime 이메일", text: $destination)
                    .textContentType(.telephoneNumber)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(14)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))

                HStack(spacing: 12) {
                    Button {
                        openFaceTimeAudio()
                    } label: {
                        Label("FaceTime 오디오", systemImage: "phone.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(.green.opacity(0.72), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button {
                        guard MFMessageComposeViewController.canSendText() else {
                            phoneStatus = "이 iPad에서 메시지 전송을 사용할 수 없습니다. Apple 계정 또는 iPhone 메시지 전달을 설정해 주세요."
                            return
                        }
                        showingMessageComposer = true
                    } label: {
                        Label("메시지 작성", systemImage: "message.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.accentColor.opacity(0.82), in: RoundedRectangle(cornerRadius: 14))
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .buttonStyle(.plain)

                if let phoneStatus {
                    Text(phoneStatus)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.orange)
                }
                Text("FaceTime 버튼은 통화를 시작합니다. 메시지는 Apple의 작성 화면에서 내용을 확인한 뒤 직접 전송합니다.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.54))
            }
            .padding(17)
            .dashboardCard(cornerRadius: 20)

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
        .sheet(isPresented: $showingMessageComposer) {
            SystemMessageComposer(
                recipients: destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? [] : [destination],
                body: latestMessage.map { "\($0.title)\n\($0.detail)" } ?? ""
            )
            .ignoresSafeArea()
        }
    }

    private func openFaceTimeAudio() {
        let trimmed = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~+@")
        guard let escaped = trimmed.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "facetime-audio://\(escaped)") else {
            phoneStatus = "전화번호 또는 FaceTime 이메일을 확인해 주세요."
            return
        }
        openURL(url) { accepted in
            if !accepted { phoneStatus = "FaceTime을 열 수 없습니다. iPad에 FaceTime이 설치되어 있는지 확인해 주세요." }
        }
    }
}

private struct SystemMessageComposer: UIViewControllerRepresentable {
    let recipients: [String]
    let body: String

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let controller = MFMessageComposeViewController()
        controller.messageComposeDelegate = context.coordinator
        controller.recipients = recipients.isEmpty ? nil : recipients
        controller.body = body
        return controller
    }

    func updateUIViewController(_ controller: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
            controller.dismiss(animated: true)
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
