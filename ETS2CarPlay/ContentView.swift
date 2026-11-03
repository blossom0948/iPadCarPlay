import Combine
import SwiftData
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @StateObject private var model = AppModel()
    @StateObject private var wallpaperStore = WallpaperStore()
    @StateObject private var layoutStore = AppLayoutStore()
    @StateObject private var splitShortcutStore = SplitShortcutStore()
    @StateObject private var updateChecker = AppUpdateChecker()
    @StateObject private var youtubeBrowser = MediaWebBrowser()
    @AppStorage("selectedWallpaperID") private var selectedWallpaperID = WallpaperPreset.carPlayClassic.rawValue
    @AppStorage("speedUnit") private var speedUnit = "km/h"
    @AppStorage("showStatusBar") private var showStatusBar = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("screenAspect") private var screenAspect = "ipad"
    @AppStorage("didMigrateToIPadCanvas") private var didMigrateToIPadCanvas = false
    @AppStorage("didMigrateToCarPlayWallpaper") private var didMigrateToCarPlayWallpaper = false
    @AppStorage("appIconScale") private var appIconScale = 1.0
    @State private var splitMediaEnabled = false
    @AppStorage("splitMediaRatio") private var splitMediaRatio = 0.54
    @AppStorage("bridgeHost") private var bridgeHost = ""
    @AppStorage("bridgePort") private var bridgePort = 8765
    @State private var mediaService: YouTubeService = .youtube
    @State private var activeSplitPair: SplitPair?

    private var activePreset: WallpaperPreset {
        WallpaperPreset(rawValue: selectedWallpaperID) ?? .carPlayClassic
    }

    var body: some View {
        GeometryReader { geometry in
            let isCarPlayAspect = screenAspect == "carPlay"
            let referenceAspect: CGFloat = 8.0 / 3.0
            let screenHeight = isCarPlayAspect && geometry.size.width > geometry.size.height
                ? min(geometry.size.height, geometry.size.width / referenceAspect)
                : geometry.size.height
            let railWidth = min(320, max(72, geometry.size.width * 0.085))

            ZStack {
                Color.black.ignoresSafeArea()

                ZStack {
                    WallpaperCanvas(preset: activePreset, image: selectedWallpaperImage)
                        .overlay(Color.black.opacity(model.selection == .apps ? 0.04 : 0.48))

                    HStack(spacing: 0) {
                        SideRail(
                            bridge: model.bridge,
                            selection: model.selection,
                            showStatusBar: showStatusBar,
                            railWidth: railWidth,
                            railHeight: screenHeight,
                            splitMediaEnabled: splitMediaEnabled,
                            onToggleSplit: toggleSplit
                        ) { section in
                            selectSection(section)
                        }

                        Group {
                            if splitMediaEnabled {
                                let pair = activeSplitPair ?? splitPairForCurrentSelection
                                MediaSplitView(pair: pair, ratio: $splitMediaRatio, browser: youtubeBrowser) {
                                    screen(for: pair.primary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                            } else if model.selection == .apps {
                                activeScreen
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                        removal: .opacity
                                    ))
                            } else {
                                activeScreen
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .transition(.asymmetric(
                                        insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                        removal: .opacity
                                    ))
                            }
                        }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .animation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88), value: splitMediaEnabled)
                    }
                }
                .frame(width: geometry.size.width, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: isCarPlayAspect ? min(40, screenHeight * 0.065) : 0, style: .continuous))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = keepScreenAwake
            }
            .task {
                if !didMigrateToIPadCanvas {
                    screenAspect = "ipad"
                    didMigrateToIPadCanvas = true
                }
                if !didMigrateToCarPlayWallpaper {
                    selectedWallpaperID = WallpaperPreset.carPlayClassic.rawValue
                    didMigrateToCarPlayWallpaper = true
                }
                if activeSplitPair == nil, let recent = splitShortcutStore.recent {
                    activeSplitPair = recent
                    mediaService = recent.media
                }
                model.attach(modelContext: modelContext)
                if !bridgeHost.isEmpty {
                    model.bridge.connect(host: bridgeHost, port: bridgePort, pairingCode: "")
                }
                Task { await updateChecker.checkIfNeeded() }
            }
            .onChange(of: keepScreenAwake) { _, shouldStayAwake in
                UIApplication.shared.isIdleTimerDisabled = shouldStayAwake
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .preferredColorScheme(appearance == "system" ? nil : (appearance == "light" ? .light : .dark))
        .statusBarHidden(true)
        .ignoresSafeArea()
    }

    private var selectedWallpaperImage: UIImage? {
        if selectedWallpaperID == "custom" { return wallpaperStore.customImage }
        return nil
    }

    private var splitPairForCurrentSelection: SplitPair {
        let service: YouTubeService
        let primary: AppSection
        switch model.selection {
        case .apps:
            primary = .dashboard
            service = mediaService
        case .youtube:
            primary = .dashboard
            service = .youtube
        case .youtubeMusic:
            primary = .dashboard
            service = .youtubeMusic
        default:
            primary = model.selection
            service = mediaService
        }
        return SplitPair(primary: primary, media: service)
    }

    @ViewBuilder
    private var activeScreen: some View {
        screen(for: model.selection)
    }

    @ViewBuilder
    private func screen(for section: AppSection) -> some View {
        switch section {
        case .dashboard:
            DashboardScreen(model: model, speedUnit: speedUnit)
        case .apps:
            AppsScreen(
                layoutStore: layoutStore,
                onSelect: selectSection,
                preferredColumns: 4,
                iconScale: appIconScale,
                recentSplit: splitShortcutStore.recent,
                favoriteSplits: splitShortcutStore.favorites,
                isFavorite: splitShortcutStore.isFavorite,
                onOpenSplit: openSplitPair,
                onToggleFavorite: splitShortcutStore.toggleFavorite
            )
        case .navigation:
            NavigationScreen(model: model, speedUnit: speedUnit)
        case .music:
            MusicScreen(player: model.audio)
        case .youtube:
            YouTubeScreen(initialService: .youtube, browser: youtubeBrowser)
        case .youtubeMusic:
            YouTubeScreen(initialService: .youtubeMusic, browser: youtubeBrowser)
        case .phone:
            VirtualPhoneScreen(model: model)
        case .messages:
            MessagesScreen(model: model)
        case .voice:
            VoiceAssistantScreen(model: model)
        case .stats:
            StatsScreen(model: model, speedUnit: speedUnit)
        case .controls:
            ControlsScreen(model: model)
        case .settings:
            SettingsScreen(
                model: model,
                updateChecker: updateChecker,
                keepScreenAwake: $keepScreenAwake,
                showStatusBar: $showStatusBar,
                selectedWallpaperID: $selectedWallpaperID,
                wallpaperStore: wallpaperStore,
                layoutStore: layoutStore,
                appearance: $appearance,
                speedUnit: $speedUnit,
                screenAspect: $screenAspect,
                appIconScale: $appIconScale
            )
        }
    }

    private func toggleSplit() {
        if splitMediaEnabled {
            withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.86)) {
                splitMediaEnabled = false
            }
            return
        }

        let pair = splitPairForCurrentSelection
        activeSplitPair = pair
        splitShortcutStore.remember(pair)
        withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.86)) {
            splitMediaEnabled = true
        }
    }

    private func openSplitPair(_ pair: SplitPair) {
        activeSplitPair = pair
        mediaService = pair.media
        splitShortcutStore.remember(pair)
        model.select(pair.primary, reduceMotion: reduceMotion)
        withAnimation(reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.86)) {
            splitMediaEnabled = true
        }
    }

    private func selectSection(_ section: AppSection) {
        if section == .apps {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                splitMediaEnabled = false
                model.selection = .apps
            }
            return
        }

        if section == .youtube || section == .youtubeMusic {
            mediaService = section == .youtube ? .youtube : .youtubeMusic
            if splitMediaEnabled {
                let current = activeSplitPair ?? splitPairForCurrentSelection
                let pair = SplitPair(primary: current.primary, media: mediaService)
                activeSplitPair = pair
                splitShortcutStore.remember(pair)
            }
        } else if splitMediaEnabled {
            let current = activeSplitPair ?? splitPairForCurrentSelection
            let pair = SplitPair(primary: section, media: current.media)
            activeSplitPair = pair
            splitShortcutStore.remember(pair)
        }
        model.select(section, reduceMotion: reduceMotion)
    }
}

private extension AppModel {
    func select(_ section: AppSection, reduceMotion: Bool) {
        if reduceMotion {
            selection = section
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                selection = section
            }
        }
    }
}

private struct SideRail: View {
    @ObservedObject var bridge: BridgeConnectionManager
    let selection: AppSection
    let showStatusBar: Bool
    let railWidth: CGFloat
    let railHeight: CGFloat
    let splitMediaEnabled: Bool
    let onToggleSplit: () -> Void
    let onSelect: (AppSection) -> Void

    private let dockItems: [AppSection] = [.navigation, .music, .phone]

    var body: some View {
        VStack(spacing: 0) {
            if showStatusBar {
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(context.date.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: min(30, max(12, railHeight * 0.045)), weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        HStack(spacing: 4) {
                            Image(systemName: "wifi")
                                .font(.system(size: min(22, max(10, railHeight * 0.032)), weight: .semibold))
                            Circle()
                                .fill(statusColor)
                                .frame(width: min(8, max(4, railHeight * 0.009)), height: min(8, max(4, railHeight * 0.009)))
                        }
                        .foregroundStyle(.white.opacity(0.86))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(bridge.isConnected ? "ETS2 연결됨" : "ETS2 연결 대기")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, railWidth * 0.11)
                .frame(height: min(82, max(42, railHeight * 0.15)), alignment: .topLeading)
            } else {
                Spacer().frame(height: 12)
            }

            Spacer(minLength: 12)
            VStack(spacing: max(4, railHeight * 0.027)) {
                ForEach(dockItems) { item in dockButton(item) }
            }
            .offset(y: railHeight * 0.01)

            Spacer(minLength: 12)
            splitButton
                .padding(.bottom, 10)

            Spacer(minLength: 8)
            dockButton(.apps)
                .padding(.bottom, 8)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        .modifier(AdaptiveLiquidGlass(cornerRadius: 0))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1)
        }
    }

    private var dockIconSize: CGFloat { railWidth * 0.55 }

    private var splitButton: some View {
        Button(action: onToggleSplit) {
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: dockIconSize * 0.50, weight: .semibold))
                .modifier(SplitIconMotion(enabled: splitMediaEnabled))
                .foregroundStyle(.white)
                .frame(width: dockIconSize + 8, height: dockIconSize + 8)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(splitMediaEnabled ? 0.24 : 0.08))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(splitMediaEnabled ? 0.36 : 0.10), lineWidth: 1)
                }
        }
        .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.91))
        .accessibilityLabel(splitMediaEnabled ? "분할 화면 닫기" : "대시보드와 미디어 분할 화면 열기")
        .accessibilityAddTraits(splitMediaEnabled ? .isSelected : [])
    }

    private var statusColor: Color {
        guard bridge.isConnected else { return .white.opacity(0.56) }
        switch bridge.gameState {
        case .live: return Color.green
        case .paused: return Color.orange
        case .stale: return Color.red
        case .waitingForGame: return Color.yellow
        }
    }

    private func dockButton(_ item: AppSection) -> some View {
        Button {
            onSelect(item)
        } label: {
            Group {
                if item == .apps {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: dockIconSize * 0.48, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .frame(width: dockIconSize + 8, height: dockIconSize + 8)
                        .background(Color.white.opacity(selection == item ? 0.22 : 0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                } else {
                    MiniDockIcon(section: item, isSelected: selection == item)
                        .frame(width: dockIconSize, height: dockIconSize)
                }
            }
            .frame(width: dockIconSize + 8, height: dockIconSize + 8)
            .contentShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(item == .apps ? "홈 화면" : item.title)
        .accessibilityAddTraits(selection == item ? .isSelected : [])
    }
}

private struct AdaptiveLiquidGlass: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content.background(Color.black.opacity(0.78))
        }
    }
}

private struct SplitIconMotion: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let enabled: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.symbolEffect(.bounce, value: enabled)
        }
    }
}

private struct MediaSplitView<Primary: View>: View {
    let pair: SplitPair
    @Binding var ratio: Double
    @ObservedObject var browser: MediaWebBrowser
    let primary: Primary
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(pair: SplitPair, ratio: Binding<Double>, browser: MediaWebBrowser, @ViewBuilder primary: () -> Primary) {
        self.pair = pair
        _ratio = ratio
        self.browser = browser
        self.primary = primary()
    }

    var body: some View {
        GeometryReader { geometry in
            let dividerWidth: CGFloat = 20
            let usableWidth = max(0, geometry.size.width - dividerWidth)
            let leadingWidth = usableWidth * CGFloat(min(max(ratio, 0.34), 0.66))

            HStack(spacing: 0) {
                primary
                    .frame(width: leadingWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()

                SplitPaneDivider(ratio: $ratio, totalWidth: usableWidth)
                    .frame(width: dividerWidth)

                YouTubeScreen(initialService: pair.media, browser: browser)
                    .id(pair.media)
                    .frame(width: usableWidth - leadingWidth)
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 10)
            .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88), value: ratio)
        }
    }
}

private struct SplitPaneDivider: View {
    @Binding var ratio: Double
    let totalWidth: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragStartRatio: Double?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.001))
            Capsule()
                .fill(Color.white.opacity(0.34))
                .frame(width: 4, height: 66)
                .shadow(color: .black.opacity(0.18), radius: 5)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartRatio == nil { dragStartRatio = ratio }
                    let startRatio = dragStartRatio ?? ratio
                    let proposed = startRatio + Double(value.translation.width / max(totalWidth, 1))
                    ratio = min(max(proposed, 0.34), 0.66)
                }
                .onEnded { _ in dragStartRatio = nil }
        )
        .accessibilityElement()
        .accessibilityLabel("분할 화면 크기 조절")
        .accessibilityValue("왼쪽 \(Int(ratio * 100))퍼센트")
        .accessibilityAdjustableAction { direction in
            guard !reduceMotion else { return }
            switch direction {
            case .increment: ratio = min(ratio + 0.04, 0.66)
            case .decrement: ratio = max(ratio - 0.04, 0.34)
            @unknown default: break
            }
        }
    }
}

private struct LauncherMenuGlyph: View {
    let side: CGFloat

    var body: some View {
        HStack(spacing: side * 0.07) {
            RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                .fill(.white)
                .frame(width: side * 0.18, height: side * 0.48)
            VStack(spacing: side * 0.08) {
                RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                    .fill(.white)
                    .frame(width: side * 0.50, height: side * 0.18)
                RoundedRectangle(cornerRadius: side * 0.035, style: .continuous)
                    .fill(.white)
                    .frame(width: side * 0.50, height: side * 0.18)
            }
        }
        .frame(width: side * 0.80, height: side * 0.55)
    }
}

private struct MiniDockIcon: View {
    let section: AppSection
    var isSelected = false

    var body: some View {
        AppIconTile(section: section, isSelected: isSelected)
    }
}

struct CarPlayPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.68),
                value: configuration.isPressed
            )
    }
}

struct WallpaperCanvas: View {
    let preset: WallpaperPreset
    var image: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else if preset == .carPlayClassic {
                    CarPlayWallpaperArt()
                } else {
                    LinearGradient(
                        colors: preset.colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Circle()
                        .fill(preset.colors[1].opacity(0.82))
                        .frame(width: geometry.size.width * 0.68)
                        .blur(radius: geometry.size.width * 0.075)
                        .offset(x: geometry.size.width * 0.28, y: -geometry.size.height * 0.22)

                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [preset.accent.opacity(0.85), preset.colors[0].opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: geometry.size.width * 1.1, height: geometry.size.height * 0.52)
                        .rotationEffect(.degrees(-24))
                        .blur(radius: geometry.size.width * 0.045)
                        .offset(x: -geometry.size.width * 0.12, y: geometry.size.height * 0.24)

                    Circle()
                        .fill(preset.colors[2].opacity(0.76))
                        .frame(width: geometry.size.width * 0.48)
                        .blur(radius: geometry.size.width * 0.08)
                        .offset(x: -geometry.size.width * 0.36, y: geometry.size.height * 0.39)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

private struct CarPlayWallpaperArt: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.25, green: 0.63, blue: 0.84),
                        Color(red: 0.62, green: 0.79, blue: 0.71),
                        Color(red: 0.92, green: 0.72, blue: 0.46),
                        Color(red: 0.43, green: 0.45, blue: 0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                CarPlayWallpaperWave(layer: .blueSweep)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.10, green: 0.34, blue: 0.56), Color(red: 0.14, green: 0.55, blue: 0.70)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.58)
                    .blur(radius: geometry.size.width * 0.006)
                CarPlayWallpaperWave(layer: .goldSweep)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.82, green: 0.66, blue: 0.34), Color(red: 0.97, green: 0.80, blue: 0.48), Color(red: 0.88, green: 0.55, blue: 0.37)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.60)
                    .blur(radius: geometry.size.width * 0.007)
                CarPlayWallpaperWave(layer: .purpleTop)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.57, green: 0.54, blue: 0.79), Color(red: 0.28, green: 0.32, blue: 0.61)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.68)
                CarPlayWallpaperWave(layer: .deepBlueCorner)
                    .fill(Color(red: 0.15, green: 0.25, blue: 0.48).opacity(0.44))
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}

private struct CarPlayWallpaperWave: Shape {
    enum Layer {
        case blueSweep
        case goldSweep
        case purpleTop
        case deepBlueCorner
    }

    let layer: Layer

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        switch layer {
        case .blueSweep:
            path.move(to: CGPoint(x: 0, y: h * 0.23))
            path.addCurve(to: CGPoint(x: w * 0.28, y: h * 0.54), control1: CGPoint(x: w * 0.13, y: h * 0.25), control2: CGPoint(x: w * 0.15, y: h * 0.46))
            path.addCurve(to: CGPoint(x: w * 0.61, y: h * 0.68), control1: CGPoint(x: w * 0.40, y: h * 0.61), control2: CGPoint(x: w * 0.50, y: h * 0.59))
            path.addCurve(to: CGPoint(x: w, y: h * 0.76), control1: CGPoint(x: w * 0.75, y: h * 0.72), control2: CGPoint(x: w * 0.88, y: h * 0.83))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()

        case .goldSweep:
            path.move(to: CGPoint(x: w * 0.16, y: 0))
            path.addCurve(to: CGPoint(x: w * 0.48, y: h * 0.40), control1: CGPoint(x: w * 0.31, y: h * 0.06), control2: CGPoint(x: w * 0.33, y: h * 0.27))
            path.addCurve(to: CGPoint(x: w, y: h * 0.42), control1: CGPoint(x: w * 0.66, y: h * 0.59), control2: CGPoint(x: w * 0.82, y: h * 0.48))
            path.addLine(to: CGPoint(x: w, y: h * 0.63))
            path.addCurve(to: CGPoint(x: w * 0.54, y: h * 0.58), control1: CGPoint(x: w * 0.84, y: h * 0.66), control2: CGPoint(x: w * 0.70, y: h * 0.65))
            path.addCurve(to: CGPoint(x: 0, y: h * 0.47), control1: CGPoint(x: w * 0.37, y: h * 0.58), control2: CGPoint(x: w * 0.16, y: h * 0.44))
            path.closeSubpath()

        case .purpleTop:
            path.move(to: CGPoint(x: w * 0.70, y: 0))
            path.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.22), control1: CGPoint(x: w * 0.77, y: h * 0.03), control2: CGPoint(x: w * 0.78, y: h * 0.18))
            path.addCurve(to: CGPoint(x: w, y: h * 0.17), control1: CGPoint(x: w * 0.94, y: h * 0.26), control2: CGPoint(x: w * 0.97, y: h * 0.21))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()

        case .deepBlueCorner:
            path.move(to: CGPoint(x: w * 0.66, y: h))
            path.addCurve(to: CGPoint(x: w, y: h * 0.82), control1: CGPoint(x: w * 0.81, y: h * 0.88), control2: CGPoint(x: w * 0.93, y: h * 0.83))
            path.addLine(to: CGPoint(x: w, y: h))
            path.closeSubpath()
        }

        return path
    }
}

struct AppIconTile: View {
    let section: AppSection
    var isSelected = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let cornerRadius = side * 0.23

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(iconBackground)
                .overlay {
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), .clear, Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
                .overlay {
                    Image(systemName: section.symbol)
                        .font(.system(size: side * 0.48, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(section == .settings ? Color.black.opacity(0.62) : Color.white)
                        .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(isSelected ? 0.85 : 0.22), lineWidth: isSelected ? 2 : 1)
                }
                .shadow(color: .black.opacity(isSelected ? 0.28 : 0.14), radius: isSelected ? 12 : 4, y: isSelected ? 6 : 2)
                .scaleEffect(isSelected && !reduceMotion ? 1.045 : 1)
                .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.68), value: isSelected)
        }
    }

    private var iconBackground: LinearGradient {
        if section == .settings {
            return LinearGradient(
                colors: [Color(white: 0.96), Color(white: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if section == .youtube {
            return LinearGradient(colors: [Color(red: 1.0, green: 0.22, blue: 0.19), Color(red: 0.78, green: 0.03, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .youtubeMusic {
            return LinearGradient(colors: [Color(red: 0.88, green: 0.12, blue: 0.20), Color(red: 0.49, green: 0.04, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .dashboard {
            return LinearGradient(colors: [Color(red: 0.17, green: 0.28, blue: 0.50), Color(red: 0.07, green: 0.10, blue: 0.22)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .controls {
            return LinearGradient(colors: [Color(red: 0.24, green: 0.61, blue: 0.92), Color(red: 0.10, green: 0.32, blue: 0.76)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .navigation {
            return LinearGradient(colors: [Color(red: 0.38, green: 0.79, blue: 0.47), Color(red: 0.91, green: 0.73, blue: 0.30), Color(red: 0.17, green: 0.64, blue: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .music {
            return LinearGradient(colors: [Color(red: 1.00, green: 0.31, blue: 0.47), Color(red: 0.78, green: 0.04, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .phone {
            return LinearGradient(colors: [Color(red: 0.34, green: 0.86, blue: 0.46), Color(red: 0.08, green: 0.64, blue: 0.31)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if section == .messages {
            return LinearGradient(colors: [Color(red: 0.42, green: 0.91, blue: 0.48), Color(red: 0.12, green: 0.66, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(
            colors: [section.color, section.color.opacity(0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

}

private struct CarPlayIconArtwork: View {
    let section: AppSection
    let side: CGFloat

    var body: some View {
        Group {
            switch section {
            case .navigation:
                MapsArtwork(side: side)
            case .dashboard:
                NowPlayingWaveform(side: side)
            case .voice:
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: side * 0.48, weight: .medium))
                    .foregroundStyle(.white)
            case .youtube:
                ZStack {
                    RoundedRectangle(cornerRadius: side * 0.15, style: .continuous)
                        .fill(.white)
                        .frame(width: side * 0.67, height: side * 0.47)
                    Image(systemName: "play.fill")
                        .font(.system(size: side * 0.26, weight: .black))
                        .foregroundStyle(Color(red: 0.88, green: 0.08, blue: 0.12))
                        .offset(x: side * 0.015)
                }
            case .youtubeMusic:
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.96))
                        .frame(width: side * 0.66, height: side * 0.66)
                    Image(systemName: "play.fill")
                        .font(.system(size: side * 0.27, weight: .black))
                        .foregroundStyle(Color(red: 0.77, green: 0.05, blue: 0.15))
                        .offset(x: side * 0.015)
                }
            case .stats:
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: side * 0.56, weight: .semibold))
                    .foregroundStyle(.white)
            case .controls:
                Image(systemName: "steeringwheel")
                    .font(.system(size: side * 0.58, weight: .medium))
                    .foregroundStyle(.white)
            case .settings:
                Image(systemName: "gearshape.fill")
                    .font(.system(size: side * 0.64, weight: .medium))
                    .foregroundStyle(LinearGradient(colors: [Color(white: 0.55), Color(white: 0.34)], startPoint: .top, endPoint: .bottom))
            case .music:
                DoubleMusicNotes()
                .foregroundStyle(.white)
            case .phone, .messages:
                Image(systemName: section.symbol)
                    .font(.system(size: side * (section == .phone ? 0.56 : 0.57), weight: .semibold))
                    .foregroundStyle(.white)
            case .apps:
                Image(systemName: "rectangle.grid.2x2.fill")
                    .font(.system(size: side * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: .black.opacity(section == .settings ? 0.08 : 0.12), radius: 2, y: 1)
    }
}

private struct MapsArtwork: View {
    let side: CGFloat

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                LinearGradient(colors: [Color(red: 0.95, green: 0.80, blue: 0.43), Color(red: 0.85, green: 0.88, blue: 0.67)], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [Color(red: 0.43, green: 0.79, blue: 0.56), Color(red: 0.31, green: 0.68, blue: 0.56)], startPoint: .top, endPoint: .bottom)
                LinearGradient(colors: [Color(red: 0.45, green: 0.80, blue: 0.92), Color(red: 0.30, green: 0.59, blue: 0.86)], startPoint: .top, endPoint: .bottom)
            }
            .clipShape(RoundedRectangle(cornerRadius: side * 0.18, style: .continuous))
            MapRoad()
                .stroke(Color.white.opacity(0.88), style: StrokeStyle(lineWidth: side * 0.026, lineCap: .round, lineJoin: .round))
                .padding(side * 0.08)
            Image(systemName: "location.north.circle.fill")
                .font(.system(size: side * 0.34, weight: .bold))
                .foregroundStyle(Color(red: 0.10, green: 0.42, blue: 0.96))
                .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
                .offset(x: -side * 0.13, y: side * 0.13)
        }
        .frame(width: side, height: side)
    }
}

private struct MapRoad: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.15, y: rect.height * 0.12))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.82, y: rect.height * 0.82),
            control1: CGPoint(x: rect.width * 0.58, y: rect.height * 0.20),
            control2: CGPoint(x: rect.width * 0.42, y: rect.height * 0.76)
        )
        path.move(to: CGPoint(x: rect.width * 0.69, y: rect.height * 0.02))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.18, y: rect.height * 0.94),
            control1: CGPoint(x: rect.width * 0.61, y: rect.height * 0.38),
            control2: CGPoint(x: rect.width * 0.26, y: rect.height * 0.50)
        )
        path.move(to: CGPoint(x: rect.width * 0.02, y: rect.height * 0.68))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.91, y: rect.height * 0.64),
            control1: CGPoint(x: rect.width * 0.31, y: rect.height * 0.50),
            control2: CGPoint(x: rect.width * 0.56, y: rect.height * 0.78)
        )
        return path
    }
}

private struct NowPlayingWaveform: View {
    let side: CGFloat
    private let heights: [CGFloat] = [0.24, 0.42, 0.58, 0.38, 0.68, 0.48, 0.62, 0.30]

    var body: some View {
        HStack(alignment: .center, spacing: side * 0.025) {
            ForEach(heights.indices, id: \.self) { index in
                Capsule()
                    .fill(LinearGradient(colors: [.red, .pink, .purple], startPoint: .top, endPoint: .bottom))
                    .frame(width: side * 0.04, height: side * heights[index])
            }
        }
    }
}

private struct DoubleMusicNotes: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        path.addEllipse(in: CGRect(x: w * 0.12, y: h * 0.61, width: w * 0.22, height: h * 0.15))
        path.addEllipse(in: CGRect(x: w * 0.57, y: h * 0.50, width: w * 0.22, height: h * 0.15))
        path.addRoundedRect(in: CGRect(x: w * 0.29, y: h * 0.20, width: w * 0.08, height: h * 0.48), cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        path.addRoundedRect(in: CGRect(x: w * 0.74, y: h * 0.09, width: w * 0.08, height: h * 0.48), cornerSize: CGSize(width: w * 0.04, height: w * 0.04))
        path.move(to: CGPoint(x: w * 0.33, y: h * 0.20))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.09))
        path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.21))
        path.addLine(to: CGPoint(x: w * 0.33, y: h * 0.33))
        path.closeSubpath()
        return path
    }
}

extension View {
    func dashboardCard(cornerRadius: CGFloat = 26) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.52))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
