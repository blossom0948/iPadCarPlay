import PhotosUI
import SwiftUI
import UIKit
import UserNotifications

struct SettingsScreen: View {
    @ObservedObject var model: AppModel
    @ObservedObject var updateChecker: AppUpdateChecker
    @Binding var keepScreenAwake: Bool
    @Binding var showStatusBar: Bool
    @Binding var selectedWallpaperID: String
    @ObservedObject var wallpaperStore: WallpaperStore
    @ObservedObject var layoutStore: AppLayoutStore
    @Binding var appearance: String
    @Binding var speedUnit: String
    @State private var selectedCategory: SettingsCategory? = .wallpaper

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                Section("ETS2 CARPLAY") {
                    ForEach(SettingsCategory.allCases) { category in
                        Label {
                            Text(category.title)
                        } icon: {
                            Image(systemName: category.symbol)
                                .foregroundStyle(category.color)
                        }
                        .tag(category as SettingsCategory?)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("설정")
            .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 285)
        } detail: {
            Group {
                switch selectedCategory ?? .wallpaper {
                case .wallpaper:
                    WallpaperSettingsView(selectedWallpaperID: $selectedWallpaperID, wallpaperStore: wallpaperStore)
                case .apps:
                    AppLayoutSettingsView(store: layoutStore)
                case .general:
                    GeneralSettingsView(keepScreenAwake: $keepScreenAwake, updateChecker: updateChecker)
                case .display:
                    DisplaySettingsView(showStatusBar: $showStatusBar, appearance: $appearance, speedUnit: $speedUnit)
                case .sound:
                    SoundSettingsView()
                case .alerts:
                    AlertSettingsView()
                case .connection:
                    ConnectionSettingsView(model: model)
                case .about:
                    AboutSettingsView(model: model)
                }
            }
            .navigationTitle((selectedCategory ?? .wallpaper).title)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .navigationSplitViewStyle(.balanced)
        .tint(.blue)
    }
}

private struct WallpaperSettingsView: View {
    @Binding var selectedWallpaperID: String
    @ObservedObject var wallpaperStore: WallpaperStore
    @State private var photoItem: PhotosPickerItem?
    @State private var importError: String?
    private let columns = [GridItem(.adaptive(minimum: 145), spacing: 14)]

    private var activePreset: WallpaperPreset { WallpaperPreset(rawValue: selectedWallpaperID) ?? .aurora }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("배경화면")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("앱 배경을 선택하거나 사진 보관함에서 원하는 사진을 추가하세요.")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .bottomLeading) {
                    WallpaperCanvas(preset: activePreset, image: selectedWallpaperID == "custom" ? wallpaperStore.customImage : nil)
                        .frame(height: 170)
                    LinearGradient(colors: [.clear, .black.opacity(0.56)], startPoint: .center, endPoint: .bottom)
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("현재 배경화면")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.78))
                            Text(selectedWallpaperID == "custom" ? "내 사진" : activePreset.name)
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 23))
                            .foregroundStyle(.white)
                    }
                    .padding(16)
                }
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        Text("기본 배경")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Text("\(WallpaperPreset.allCases.count)개")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    Text("앱에서 제공하는 배경 디자인입니다. Apple 시스템 배경화면 파일을 포함하지 않습니다.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(WallpaperPreset.allCases) { preset in
                            WallpaperChoiceButton(name: preset.name, preset: preset, image: nil, isSelected: selectedWallpaperID == preset.rawValue) {
                                selectedWallpaperID = preset.rawValue
                            }
                        }
                        if let customImage = wallpaperStore.customImage {
                            WallpaperChoiceButton(name: "내 사진", preset: .aurora, image: customImage, isSelected: selectedWallpaperID == "custom") {
                                selectedWallpaperID = "custom"
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 11) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("사진에서 배경 추가", systemImage: "photo.badge.plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    Text("선택한 사진은 이 앱의 저장 공간에 보관됩니다.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                    if let importError {
                        Text(importError).font(.system(size: 12, weight: .medium)).foregroundStyle(.red)
                    }
                }
                .padding(17)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(22)
        }
        .scrollIndicators(.hidden)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if await wallpaperStore.importPhoto(from: item) {
                    selectedWallpaperID = "custom"
                    importError = nil
                } else {
                    importError = "사진을 불러오지 못했습니다. 다른 사진을 선택해 주세요."
                }
            }
        }
    }
}

private struct WallpaperChoiceButton: View {
    let name: String
    let preset: WallpaperPreset
    let image: UIImage?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                WallpaperCanvas(preset: preset, image: image)
                    .frame(height: 93)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 19))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(7)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.10), lineWidth: isSelected ? 2 : 1)
                    }
                Text(name)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(name) 배경화면")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AppLayoutSettingsView: View {
    @ObservedObject var store: AppLayoutStore

    var body: some View {
        List {
            Section {
                ForEach(store.orderedSections) { section in
                    Toggle(isOn: Binding(get: { !store.hiddenSections.contains(section) }, set: { store.setVisible($0, for: section) })) {
                        Label(section.title, systemImage: section.symbol)
                    }
                }
                .onMove(perform: store.move)
            } header: {
                Text("앱 아이콘")
            } footer: {
                Text("표시할 앱을 고르고 순서를 바꾸세요. 이 설정은 앱 화면에 반영됩니다.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .toolbar { EditButton() }
    }
}

private struct GeneralSettingsView: View {
    @Binding var keepScreenAwake: Bool
    @ObservedObject var updateChecker: AppUpdateChecker

    var body: some View {
        Form {
            Section("운행 화면") {
                Toggle("운행 중 화면 유지", isOn: $keepScreenAwake)
                Text("켜면 앱이 열려 있는 동안 iPad 화면이 자동으로 잠기지 않습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("데이터") {
                Label("실시간 값은 연결된 ETS2에서 수신", systemImage: "waveform.path.ecg")
                Label("운행 기록은 iPad에 저장", systemImage: "externaldrive")
            }
            Section("소프트웨어 업데이트") {
                LabeledContent("설치된 버전", value: updateChecker.currentVersion)
                switch updateChecker.state {
                case .idle:
                    Label("앱을 열 때 새 버전을 확인합니다.", systemImage: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                case .checking:
                    ProgressView("GitHub 릴리스 확인 중")
                case .current:
                    Label("최신 공개 릴리스가 설치되어 있습니다.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                case .available(let version, let notes):
                    VStack(alignment: .leading, spacing: 7) {
                        Label("새 버전: \(version)", systemImage: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        if !notes.isEmpty { Text(String(notes.prefix(700))).font(.footnote).foregroundStyle(.secondary) }
                        Text("버전 정보와 변경 내용은 앱 안에서 확인합니다. 설치는 App Store 또는 TestFlight 배포가 구성된 뒤 해당 배포 경로에서 처리해야 합니다.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                case .noPublishedRelease:
                    Label("공개된 앱 릴리스가 아직 없습니다.", systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                case .failed(let message):
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                if let lastCheckedAt = updateChecker.lastCheckedAt {
                    LabeledContent("마지막 확인", value: lastCheckedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Button {
                    Task { await updateChecker.checkNow() }
                } label: {
                    Label("업데이트 지금 확인", systemImage: "arrow.clockwise")
                }
                .disabled(updateChecker.state == .checking)
                Text("iPadOS는 실행 중인 앱이 자기 자신을 교체 설치하는 것을 허용하지 않습니다. Xcode로 설치한 현재 빌드는 새 코드를 받을 때 Xcode에서 다시 실행해야 합니다. App Store 등록 후에는 iPad가 자동 업데이트를 설치합니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct DisplaySettingsView: View {
    @Binding var showStatusBar: Bool
    @Binding var appearance: String
    @Binding var speedUnit: String

    var body: some View {
        Form {
            Section("주행 정보") {
                Picker("속도 단위", selection: $speedUnit) {
                    Text("킬로미터/시").tag("km/h")
                    Text("마일/시").tag("mph")
                }
            }
            Section("화면 구성") {
                Picker("화면 모드", selection: $appearance) {
                    Text("어둡게").tag("dark")
                    Text("밝게").tag("light")
                    Text("기기 설정 따르기").tag("system")
                }
                Toggle("상단 상태 표시", isOn: $showStatusBar)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct SoundSettingsView: View {
    @AppStorage("duckAudioForVoice") private var duckAudioForVoice = true

    var body: some View {
        Form {
            Section("스마트 오디오") {
                Toggle("음성 안내 중 가져온 파일 음량 낮추기", isOn: $duckAudioForVoice)
                Label("Apple Music 카탈로그와 가져온 오디오 파일을 재생하고, 잠금 화면 제어를 지원합니다.", systemImage: "music.note.list")
                    .foregroundStyle(.secondary)
                Label("Apple Music 재생 음량은 MusicKit에서 직접 조절할 수 없습니다.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
                Label("YouTube 동영상은 공식 플레이어에서 직접 재생합니다.", systemImage: "play.rectangle")
                    .foregroundStyle(.secondary)
            }
            Section("음성 안내") {
                Label("한국어 음성 인식은 버튼을 눌렀을 때만 작동합니다.", systemImage: "mic")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct AlertSettingsView: View {
    @AppStorage("alerts.system.enabled") private var systemAlertsEnabled = false
    @AppStorage("alerts.fuel.enabled") private var fuelEnabled = true
    @AppStorage("alerts.speed.enabled") private var speedEnabled = true
    @AppStorage("alerts.wear.enabled") private var wearEnabled = true
    @AppStorage("alerts.fuel.threshold") private var fuelThreshold = 15.0
    @AppStorage("alerts.speed.tolerance") private var speedTolerance = 5.0
    @State private var systemAlertMessage: String?

    var body: some View {
        Form {
            Section("iPad 알림") {
                Toggle("잠금 화면 및 배너 알림", isOn: Binding(
                    get: { systemAlertsEnabled },
                    set: { enabled in
                        guard enabled else {
                            systemAlertsEnabled = false
                            systemAlertMessage = nil
                            return
                        }
                        Task {
                            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
                            await MainActor.run {
                                systemAlertsEnabled = granted
                                systemAlertMessage = granted ? nil : "iPad 설정에서 ETS2 CarPlay의 알림을 허용해 주세요."
                            }
                        }
                    }
                ))
                if let systemAlertMessage {
                    Text(systemAlertMessage)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else {
                    Text("실제 게임 이벤트와 주행 경보를 iPad 알림으로 표시합니다.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Section("자동 경보") {
                Toggle("연료 부족", isOn: $fuelEnabled)
                if fuelEnabled {
                    HStack {
                        Text("연료가 다음보다 적으면 알림")
                        Spacer()
                        Text("\(Int(fuelThreshold))%")
                            .monospacedDigit()
                    }
                    Slider(value: $fuelThreshold, in: 5...40, step: 1)
                }
                Toggle("제한 속도 초과", isOn: $speedEnabled)
                if speedEnabled {
                    HStack {
                        Text("속도 제한 초과 허용")
                        Spacer()
                        Text("\(Int(speedTolerance)) km/h")
                            .monospacedDigit()
                    }
                    Slider(value: $speedTolerance, in: 0...20, step: 1)
                }
                Toggle("차량 손상", isOn: $wearEnabled)
            }
            Section {
                Text("경보는 ETS2가 제공하는 실제 텔레메트리 값으로 생성됩니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct ConnectionSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: BridgeConnectionManager
    @AppStorage("bridgeHost") private var bridgeHost = ""
    @AppStorage("bridgePort") private var bridgePort = 8765
    @State private var pairingCode = ""

    init(model: AppModel) {
        self.model = model
        bridge = model.bridge
    }

    var body: some View {
        Form {
            Section("Windows 브리지") {
                LabeledContent("상태", value: bridge.status.label)
                LabeledContent("ETS2", value: bridge.gameState.label)
                TextField("Windows PC의 IPv4 주소", text: $bridgeHost)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.decimalPad)
                TextField("포트", value: $bridgePort, format: .number)
                    .keyboardType(.numberPad)
                SecureField("처음 연결할 때 6자리 코드", text: $pairingCode)
                    .keyboardType(.numberPad)

                Button {
                    bridge.connect(host: bridgeHost, port: bridgePort, pairingCode: pairingCode)
                    pairingCode = ""
                } label: {
                    Label(bridge.isConnected ? "다시 연결" : "연결 또는 페어링", systemImage: "point.3.connected.trianglepath.dotted")
                        .frame(maxWidth: .infinity)
                }
                .disabled(bridgeHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if bridge.status != .notConfigured && !bridgeHost.isEmpty {
                    Button("연결 해제", systemImage: "xmark.circle", role: .destructive) { bridge.disconnect() }
                    Button("페어링 삭제", systemImage: "trash", role: .destructive) { bridge.forgetPairing() }
                }
            } footer: {
                Text("같은 신뢰할 수 있는 Wi‑Fi에 연결하세요. 페어링 코드는 Windows 브리지 창에 표시되며 한 번만 사용됩니다.")
            }

            Section("연결 방법") {
                Label("WindowsBridge\\BridgeServer를 실행합니다.", systemImage: "pc")
                Label("ETS2 텔레메트리 플러그인을 게임 플러그인 폴더에 설치합니다.", systemImage: "shippingbox")
                Label("Windows 창에 나온 PC 주소와 코드를 입력합니다.", systemImage: "number")
                Link(destination: URL(string: "https://github.com/blossom0948/iPadCarPlay#readme")!) {
                    Label("설치 안내 열기", systemImage: "book")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

private struct AboutSettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var bridge: BridgeConnectionManager
    private var version: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0" }

    init(model: AppModel) {
        self.model = model
        bridge = model.bridge
    }

    var body: some View {
        Form {
            Section("ETS2 CarPlay") {
                LabeledContent("버전", value: version)
                LabeledContent("텔레메트리", value: bridge.snapshot == nil ? "수신 대기" : "실제 데이터 수신 중")
                LabeledContent("플랫폼", value: "iPadOS")
            }
            Section("인터페이스 안내") {
                Text("이 앱은 iPad에서 실행되는 CarPlay 스타일 인터페이스입니다. Apple CarPlay 시스템 앱이나 차량 디스플레이를 실행하지 않습니다.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("프로젝트") {
                Link("GitHub 저장소", destination: URL(string: "https://github.com/blossom0948/iPadCarPlay")!)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
