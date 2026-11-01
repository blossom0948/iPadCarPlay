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
            let railWidth = min(320, max(72, geometry.size.width * 0.125))

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
                    .frame(width: geometry.size.width, height: screenHeight)
                }
                .frame(width: geometry.size.width, height: screenHeight)
                .clipShape(RoundedRectangle(cornerRadius: isCarPlayAspect ? min(32, screenHeight * 0.05) : 0, style: .continuous))
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
        .background {
            if #available(iOS 26.0, *) {
                Rectangle()
                    .glassEffect(.regular, in: Rectangle())
                    .overlay(Color.black.opacity(0.24))
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(Color.black.opacity(0.26))
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1)
        }
    }

    private var statusColor: Color {
        guard bridge.isConnected else { return .white.opacity(0.56) }
        switch bridge.gameState {
        case .live: .green
        case .paused: .orange
        case .stale: .red
        case .waitingForGame: .yellow
        }
    }

    private var dockIconSize: CGFloat { railWidth * 0.38 }

    private func dockButton(_ item: AppSection) -> some View {
        Button {
            onSelect(item)
        } label: {
            Group {
                if item == .apps {
                    Image(systemName: "rectangle.grid.2x2.fill")
                        .font(.system(size: dockIconSize * 0.62, weight: .semibold))
                        .foregroundStyle(.white)
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

private struct MiniDockIcon: View {
    let section: AppSection

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            RoundedRectangle(cornerRadius: side * 0.20, style: .continuous)
                .fill(LinearGradient(
                    colors: [section == .navigation ? Color(red: 0.32, green: 0.84, blue: 0.72) : section.color, section.color.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay {
                    if section == .navigation {
                        ZStack {
                            Image(systemName: "map.fill")
                                .font(.system(size: side * 0.62, weight: .regular))
                                .foregroundStyle(.white)
                            Image(systemName: "location.fill")
                                .font(.system(size: side * 0.24, weight: .semibold))
                                .foregroundStyle(Color(red: 0.08, green: 0.43, blue: 0.96))
                                .offset(x: side * 0.05, y: side * 0.05)
                        }
                    } else {
                        Image(systemName: section.symbol)
                            .font(.system(size: side * 0.62, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: side * 0.20, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: max(0.8, side * 0.015))
                }
                .shadow(color: .black.opacity(0.18), radius: side * 0.05, y: side * 0.02)
        }
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
                        colors: [Color(red: 0.09, green: 0.35, blue: 0.62), Color(red: 0.13, green: 0.61, blue: 0.68)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.72)
                CarPlayWallpaperWave(layer: .goldSweep)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.80, green: 0.65, blue: 0.31), Color(red: 0.97, green: 0.81, blue: 0.46), Color(red: 0.90, green: 0.49, blue: 0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.74)
                CarPlayWallpaperWave(layer: .purpleTop)
                    .fill(LinearGradient(
                        colors: [Color(red: 0.56, green: 0.52, blue: 0.78), Color(red: 0.22, green: 0.25, blue: 0.55)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.82)
                CarPlayWallpaperWave(layer: .deepBlueCorner)
                    .fill(Color(red: 0.19, green: 0.23, blue: 0.52).opacity(0.56))
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
            path.move(to: CGPoint(x: 0, y: h * 0.09))
            path.addCurve(to: CGPoint(x: w * 0.27, y: h * 0.45), control1: CGPoint(x: w * 0.15, y: h * 0.18), control2: CGPoint(x: w * 0.13, y: h * 0.35))
            path.addCurve(to: CGPoint(x: w * 0.61, y: h * 0.65), control1: CGPoint(x: w * 0.39, y: h * 0.53), control2: CGPoint(x: w * 0.50, y: h * 0.51))
            path.addCurve(to: CGPoint(x: w, y: h * 0.78), control1: CGPoint(x: w * 0.73, y: h * 0.74), control2: CGPoint(x: w * 0.83, y: h * 0.88))
            path.addLine(to: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: 0, y: h))
            path.closeSubpath()

        case .goldSweep:
            path.move(to: CGPoint(x: 0, y: h * 0.38))
            path.addCurve(to: CGPoint(x: w * 0.31, y: h * 0.40), control1: CGPoint(x: w * 0.11, y: h * 0.23), control2: CGPoint(x: w * 0.21, y: h * 0.29))
            path.addCurve(to: CGPoint(x: w * 0.61, y: h * 0.73), control1: CGPoint(x: w * 0.43, y: h * 0.53), control2: CGPoint(x: w * 0.47, y: h * 0.68))
            path.addCurve(to: CGPoint(x: w, y: h * 0.56), control1: CGPoint(x: w * 0.74, y: h * 0.78), control2: CGPoint(x: w * 0.86, y: h * 0.69))
            path.addLine(to: CGPoint(x: w, y: h * 0.81))
            path.addCurve(to: CGPoint(x: w * 0.51, y: h * 0.81), control1: CGPoint(x: w * 0.82, y: h * 0.93), control2: CGPoint(x: w * 0.65, y: h * 0.91))
            path.addCurve(to: CGPoint(x: 0, y: h * 0.62), control1: CGPoint(x: w * 0.36, y: h * 0.69), control2: CGPoint(x: w * 0.16, y: h * 0.51))
            path.closeSubpath()

        case .purpleTop:
            path.move(to: CGPoint(x: w * 0.63, y: 0))
            path.addCurve(to: CGPoint(x: w * 0.85, y: h * 0.23), control1: CGPoint(x: w * 0.75, y: h * 0.06), control2: CGPoint(x: w * 0.77, y: h * 0.19))
            path.addCurve(to: CGPoint(x: w, y: h * 0.20), control1: CGPoint(x: w * 0.91, y: h * 0.27), control2: CGPoint(x: w * 0.96, y: h * 0.24))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()

        case .deepBlueCorner:
            path.move(to: CGPoint(x: w * 0.71, y: h))
            path.addCurve(to: CGPoint(x: w, y: h * 0.84), control1: CGPoint(x: w * 0.80, y: h * 0.87), control2: CGPoint(x: w * 0.92, y: h * 0.82))
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
                    Group {
                        if section == .navigation {
                            ZStack {
                                Image(systemName: "map.fill")
                                    .font(.system(size: side * 0.48, weight: .regular))
                                    .foregroundStyle(.white)
                                Image(systemName: "location.north.circle.fill")
                                    .font(.system(size: side * 0.25, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.08, green: 0.43, blue: 0.96))
                                    .offset(x: side * 0.06, y: side * 0.05)
                            }
                        } else {
                            Image(systemName: section.symbol)
                                .font(.system(size: side * symbolScale, weight: .medium))
                                .foregroundStyle(section == .settings ? Color(white: 0.36) : .white)
                        }
                    }
                    .shadow(color: .black.opacity(section == .settings ? 0 : 0.16), radius: 3, y: 1)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                }
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
        if section == .navigation {
            return LinearGradient(
                colors: [Color(red: 0.23, green: 0.86, blue: 0.68), Color(red: 0.20, green: 0.58, blue: 0.91)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [section.color, section.color.opacity(0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var symbolScale: CGFloat {
        switch section {
        case .phone, .music, .messages: 0.60
        case .dashboard: 0.72
        case .navigation: 0.40
        case .youtube: 0.68
        case .voice: 0.58
        case .stats: 0.68
        case .controls: 0.62
        case .settings: 0.64
        case .apps: 0.40
        }
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
