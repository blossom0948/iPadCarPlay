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
    @AppStorage("bridgeHost") private var bridgeHost = ""
    @AppStorage("bridgePort") private var bridgePort = 8765

    private var activePreset: WallpaperPreset {
        WallpaperPreset(rawValue: selectedWallpaperID) ?? .aurora
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                WallpaperCanvas(preset: activePreset, image: selectedWallpaperID == "custom" ? wallpaperStore.customImage : nil)
                    .overlay(Color.black.opacity(0.42))
                    .ignoresSafeArea()

                HStack(spacing: 12) {
                    SideRail(selection: model.selection) { section in
                        model.select(section, reduceMotion: reduceMotion)
                    }

                    VStack(spacing: 10) {
                        if showStatusBar {
                            TopStatusBar(bridge: model.bridge)
                        }
                        activeScreen
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(model.selection)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: geometry.size.width, height: geometry.size.height)
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
                speedUnit: $speedUnit
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

private struct TopStatusBar: View {
    @ObservedObject var bridge: BridgeConnectionManager

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 12) {
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .monospacedDigit()

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(bridge.isConnected ? "ETS2" : "연결 대기")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.84))

                Image(systemName: "wifi")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(height: 34)
        }
    }

    private var statusColor: Color {
        guard bridge.isConnected else { return .gray }
        switch bridge.gameState {
        case .live: .green
        case .paused: .orange
        case .stale: .red
        case .waitingForGame: bridge.isConnected ? .yellow : .gray
        }
    }
}

private struct SideRail: View {
    let selection: AppSection
    let onSelect: (AppSection) -> Void
    @Namespace private var dockHighlight

    private let dockItems: [AppSection] = [.navigation, .music, .phone, .messages]

    var body: some View {
        VStack(spacing: 7) {
            ForEach(dockItems) { item in dockButton(item) }

            Spacer(minLength: 8)

            Rectangle()
                .fill(Color.white.opacity(0.13))
                .frame(width: 35, height: 1)
                .padding(.bottom, 3)

            dockButton(.apps)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .frame(maxHeight: .infinity)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 23))
            } else {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 23, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func dockButton(_ item: AppSection) -> some View {
        Button {
            onSelect(item)
        } label: {
            ZStack {
                if selection == item {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color.white.opacity(0.17))
                        .matchedGeometryEffect(id: "active-dock-item", in: dockHighlight)
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        }
                }
                Image(systemName: item.symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
            }
            .foregroundStyle(selection == item ? .white : .white.opacity(0.70))
            .frame(width: 54, height: 48)
            .contentShape(RoundedRectangle(cornerRadius: 17))
        }
        .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.90))
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selection == item ? .isSelected : [])
    }
}

struct CarPlayPressButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.92
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1)
            .opacity(configuration.isPressed ? 0.84 : 1)
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

struct AppIconTile: View {
    let section: AppSection

    var body: some View {
        RoundedRectangle(cornerRadius: 23, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [section.color.opacity(0.96), section.color.opacity(0.56)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                Image(systemName: section.symbol)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
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
