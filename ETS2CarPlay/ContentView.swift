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
    @StateObject private var updateChecker = AppUpdateChecker()
    @AppStorage("selectedWallpaperID") private var selectedWallpaperID = WallpaperPreset.aurora.rawValue
    @AppStorage("speedUnit") private var speedUnit = "km/h"
    @AppStorage("showStatusBar") private var showStatusBar = true
    @AppStorage("keepScreenAwake") private var keepScreenAwake = false
    @AppStorage("appearance") private var appearance = "dark"
    @AppStorage("screenAspect") private var screenAspect = "carPlay"
    @AppStorage("bridgeHost") private var bridgeHost = ""
    @AppStorage("bridgePort") private var bridgePort = 8765

    private var activePreset: WallpaperPreset {
        WallpaperPreset(rawValue: selectedWallpaperID) ?? .aurora
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
                    WallpaperCanvas(preset: activePreset, image: selectedWallpaperID == "custom" ? wallpaperStore.customImage : nil)
                        .overlay(Color.black.opacity(model.selection == .apps ? 0.08 : 0.42))

                    HStack(spacing: 0) {
                        SideRail(bridge: model.bridge, selection: model.selection, showStatusBar: showStatusBar, railWidth: railWidth, railHeight: screenHeight) { section in
                            model.select(section, reduceMotion: reduceMotion)
                        }

                        activeScreen
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(model.selection)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.97)),
                                removal: .opacity
                            ))
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
    }

    @ViewBuilder
    private var activeScreen: some View {
        switch model.selection {
        case .dashboard:
            DashboardScreen(model: model, speedUnit: speedUnit)
        case .apps:
            AppsScreen(layoutStore: layoutStore) { model.select($0, reduceMotion: reduceMotion) }
        case .navigation:
            NavigationScreen(model: model, speedUnit: speedUnit)
        case .music:
            MusicScreen(player: model.audio)
        case .youtube:
            YouTubeScreen()
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
                screenAspect: $screenAspect
            )
        }
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
            dockButton(.apps)
                .padding(.bottom, 8)
        }
        .frame(width: railWidth)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.22))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1)
        }
    }

    private var dockIconSize: CGFloat { railWidth * 0.55 }

    private var statusColor: Color {
        guard bridge.isConnected else { return .white.opacity(0.56) }
        switch bridge.gameState {
        case .live: .green
        case .paused: .orange
        case .stale: .red
        case .waitingForGame: .yellow
        }
    }

    private func dockButton(_ item: AppSection) -> some View {
        Button {
            onSelect(item)
        } label: {
            Group {
                if item == .apps {
                    LauncherMenuGlyph(side: dockIconSize)
                } else {
                    MiniDockIcon(section: item)
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

    var body: some View {
        AppIconTile(section: section)
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
                } else if preset == .aurora {
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
                    CarPlayIconArtwork(section: section, side: side)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(section == .dashboard || section == .youtube || section == .controls
                                ? Color.black.opacity(0.10) : Color.white.opacity(0.22), lineWidth: 1)
                }
        }
    }

    private var iconBackground: LinearGradient {
        if section == .settings || section == .dashboard || section == .youtube || section == .controls {
            return LinearGradient(
                colors: section == .settings
                    ? [Color(white: 0.96), Color(white: 0.72)]
                    : [Color.white, Color(white: 0.94)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if section == .navigation {
            return LinearGradient(colors: [Color.white, Color(white: 0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
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
                Text("N")
                    .font(.system(size: side * 0.62, weight: .black, design: .default))
                    .foregroundStyle(LinearGradient(colors: [.red, Color(red: 0.82, green: 0.06, blue: 0.15)], startPoint: .top, endPoint: .bottom))
            case .stats:
                Image(systemName: "book.fill")
                    .font(.system(size: side * 0.64, weight: .medium))
                    .foregroundStyle(.white)
            case .controls:
                VStack(spacing: 0) {
                    Text("MON")
                        .font(.system(size: side * 0.18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.red)
                    Text("6")
                        .font(.system(size: side * 0.54, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(white: 0.18))
                        .offset(y: -side * 0.025)
                }
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
        .shadow(color: .black.opacity(section == .settings || section == .youtube || section == .controls ? 0 : 0.12), radius: 2, y: 1)
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
                .fill(Color.black.opacity(0.30))
        )
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }
}
