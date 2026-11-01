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

                HStack(spacing: 18) {
                    SideRail(selection: model.selection) { section in
                        model.select(section, reduceMotion: reduceMotion)
                    }

                    VStack(spacing: 18) {
                        if showStatusBar {
                            TopStatusBar(bridge: model.bridge)
                        }
                        activeScreen
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(model.selection)
                            .transition(.opacity.combined(with: .scale(scale: 0.985)))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(18)
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
            withAnimation(.easeInOut(duration: 0.22)) {
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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(context.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))

                Spacer()

                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                    Text(bridge.isConnected ? bridge.gameState.label : bridge.status.label)
                        .font(.system(size: 12, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.24), in: Capsule())

                Image(systemName: bridge.isConnected ? "network" : "network.slash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.86))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 30)
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

    private let items = AppSection.allCases

    var body: some View {
        VStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    onSelect(item)
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 19, weight: .semibold))
                            .frame(height: 22)
                        Text(item.title)
                            .font(.system(size: 9, weight: .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(selection == item ? .white : .white.opacity(0.68))
                    .frame(width: 68, height: 51)
                    .background {
                        if selection == item {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .fill(item.color.opacity(0.30))
                        }
                    }
                    .overlay(alignment: .leading) {
                        if selection == item {
                            Capsule()
                                .fill(item.color)
                                .frame(width: 3, height: 24)
                                .offset(x: -5)
                        }
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 28))
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
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
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 36, height: 36)
                    .blur(radius: 15)
                    .offset(x: 3, y: 3)
            }
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
