import SwiftUI
import SafariServices
import WebKit

enum YouTubeService: String, CaseIterable, Codable, Identifiable, Hashable {
    case youtube
    case youtubeMusic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeMusic: "YouTube Music"
        }
    }

    var shortTitle: String {
        switch self {
        case .youtube: "YouTube"
        case .youtubeMusic: "YT Music"
        }
    }

    var appSection: AppSection {
        switch self {
        case .youtube: .youtube
        case .youtubeMusic: .youtubeMusic
        }
    }

    var symbol: String {
        switch self {
        case .youtube: "play.rectangle.fill"
        case .youtubeMusic: "music.note"
        }
    }

    var homeURL: URL {
        switch self {
        case .youtube: URL(string: "https://www.youtube.com")!
        case .youtubeMusic: URL(string: "https://music.youtube.com")!
        }
    }
}

struct YouTubeScreen: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var browser: MediaWebBrowser
    @State private var service: YouTubeService
    @State private var requestedURL: URL
    @State private var addressOrSearch = ""
    @State private var errorMessage: String?
    @State private var showingSafariMusic = false

    init(initialService: YouTubeService = .youtube, browser: MediaWebBrowser) {
        self.browser = browser
        _service = State(initialValue: initialService)
        _requestedURL = State(initialValue: browser.currentURL ?? initialService.homeURL)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if service == .youtube {
                navigationBar
            }

            if service == .youtube, let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Group {
                if service == .youtube {
                    ZStack(alignment: .top) {
                        YouTubeWebView(url: requestedURL, browser: browser)
                            .background(Color.black)

                        if browser.isLoading {
                            ProgressView()
                                .controlSize(.regular)
                                .tint(.white)
                                .padding(12)
                                .background(.black.opacity(0.62), in: Capsule())
                                .padding(.top, 12)
                                .transition(.opacity)
                        }
                    }
                } else {
                    youtubeMusicFallback
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            }

            footer
        }
        .padding(16)
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84), value: service)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: browser.isLoading)
        .sheet(isPresented: $showingSafariMusic) {
            YouTubeMusicSafariView(url: YouTubeService.youtubeMusic.homeURL)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(20)
        }
        .onChange(of: service) { _, newService in
            errorMessage = nil
            addressOrSearch = ""
            requestedURL = newService == .youtube ? (browser.currentURL ?? newService.homeURL) : newService.homeURL
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                titleBlock
                Spacer(minLength: 8)
                servicePicker
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(alignment: .leading, spacing: 10) {
                titleBlock
                servicePicker
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var titleBlock: some View {
        HStack(spacing: 14) {
            Image(systemName: service.symbol)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(service == .youtube ? Color.red : Color(red: 1, green: 0.28, blue: 0.32))
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .contentTransition(reduceMotion ? .identity : .symbolEffect(.replace))

            VStack(alignment: .leading, spacing: 3) {
                Text(service.title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(service == .youtube ? "공식 YouTube 화면" : "앱 안의 Safari 보안 창")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }
        }
    }

    private var servicePicker: some View {
        HStack(spacing: 4) {
            ForEach(YouTubeService.allCases) { item in
                Button {
                    service = item
                } label: {
                    Label(item.shortTitle, systemImage: item.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .labelStyle(.titleAndIcon)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 12)
                        .frame(height: 38)
                        .foregroundStyle(service == item ? .white : .white.opacity(0.66))
                        .background {
                            if service == item {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.17))
                            }
                        }
                }
                .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.96))
                .accessibilityAddTraits(service == item ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var navigationBar: some View {
        HStack(spacing: 8) {
            browserButton("chevron.left", enabled: browser.canGoBack, label: "뒤로") { browser.goBack() }
            browserButton("chevron.right", enabled: browser.canGoForward, label: "앞으로") { browser.goForward() }
            browserButton("arrow.clockwise", enabled: true, label: "새로고침") { browser.reload() }

            TextField("검색어 또는 YouTube 주소", text: $addressOrSearch)
                .font(.system(size: 14, weight: .medium))
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .onSubmit(openAddressOrSearch)
                .accessibilityLabel("YouTube 검색 또는 주소 입력")

            Button(action: openAddressOrSearch) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 42)
                    .background(Color.red.opacity(0.90), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.93))
            .accessibilityLabel("검색 또는 열기")
        }
    }

    private var footer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .padding(.top, 1)
            Text(service == .youtubeMusic
                 ? "앱 안의 Safari 보안 창에서 공식 YouTube Music을 엽니다. 창을 닫으면 분할 화면으로 돌아옵니다. 이용 가능 기능은 Google 계정·지역·멤버십 설정에 따릅니다."
                 : "YouTube 공식 사이트의 재생 버튼, 광고와 콘텐츠 정책을 그대로 사용합니다. Google 로그인이 내장 화면에서 제한될 수 있으며, 앱은 계정 정보를 수집하지 않습니다.")
                .font(.system(size: 10, weight: .medium))
                .lineSpacing(2)
                .foregroundStyle(.white.opacity(0.58))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.white.opacity(0.52))
    }

    private var youtubeMusicFallback: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 92, height: 92)
                .background(
                    LinearGradient(colors: [.red, Color(red: 0.49, green: 0.04, blue: 0.17)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 28, style: .continuous)
                )
                .shadow(color: .red.opacity(0.22), radius: 18, y: 8)

            VStack(spacing: 7) {
                Text("앱 안에서 YouTube Music 열기")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                Text("이 버튼은 다른 앱으로 이동하지 않고, 앱 안의 Safari 보안 창에서 공식 YouTube Music을 엽니다. 창을 닫으면 이 화면과 분할 화면으로 돌아옵니다.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 520)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                showingSafariMusic = true
            } label: {
                Label("앱 안에서 YouTube Music 열기", systemImage: "safari.fill")
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .padding(.horizontal, 20)
                    .frame(height: 52)
                    .background(Color.white.opacity(0.18), in: Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1))
            }
            .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.96))
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func browserButton(_ symbol: String, enabled: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? .white : .white.opacity(0.30))
                .frame(width: 38, height: 42)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(CarPlayPressButtonStyle(pressedScale: 0.93))
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func openAddressOrSearch() {
        let value = addressOrSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        if let url = URL(string: value),
           let host = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host?.lowercased(),
           (host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")),
           url.scheme?.lowercased() == "https" {
            requestedURL = url
            errorMessage = nil
            return
        }

        var components = URLComponents(url: service.homeURL, resolvingAgainstBaseURL: false)
        components?.path = service == .youtube ? "/results" : "/search"
        components?.queryItems = [URLQueryItem(name: service == .youtube ? "search_query" : "q", value: value)]
        guard let url = components?.url else {
            errorMessage = "검색 주소를 만들지 못했어요. 다시 시도해 주세요."
            return
        }
        requestedURL = url
        errorMessage = nil
    }
}

private struct YouTubeMusicSafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) { }
}

@MainActor
final class MediaWebBrowser: ObservableObject {
    private let lastURLKey = "youtube.lastVisitedURL"
    @Published var isLoading = false
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published private(set) var currentURL: URL? = MediaWebBrowser.savedYouTubeURL()
    var webView: WKWebView?

    private static func savedYouTubeURL() -> URL? {
        guard let value = UserDefaults.standard.string(forKey: "youtube.lastVisitedURL"),
              let url = URL(string: value), isYouTubeURL(url) else { return nil }
        return url
    }

    private static func isYouTubeURL(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https", let host = url.host?.lowercased() else { return false }
        return host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be"
    }

    private func remember(_ url: URL) {
        guard Self.isYouTubeURL(url) else { return }
        currentURL = url
        UserDefaults.standard.set(url.absoluteString, forKey: lastURLKey)
    }

    func attach(_ webView: WKWebView) {
        self.webView = webView
        if currentURL == nil, let url = webView.url { remember(url) }
        refreshNavigationState()
    }

    func load(_ url: URL) {
        guard let webView else {
            currentURL = url
            return
        }
        if webView.url == url && !webView.isLoading {
            remember(url)
            refreshNavigationState()
            return
        }
        remember(url)
        webView.load(URLRequest(url: url))
        refreshNavigationState()
    }

    func navigationFinished(at url: URL?) {
        if let url { remember(url) }
        refreshNavigationState()
    }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func refreshNavigationState() {
        guard let webView else { return }
        isLoading = webView.isLoading
        canGoBack = webView.canGoBack
        canGoForward = webView.canGoForward
    }
}

private struct YouTubeWebView: UIViewRepresentable {
    let url: URL
    @ObservedObject var browser: MediaWebBrowser

    func makeUIView(context: Context) -> WKWebView {
        if let retainedWebView = browser.webView {
            retainedWebView.navigationDelegate = context.coordinator
            context.coordinator.lastRequestedURL = browser.currentURL ?? retainedWebView.url ?? url
            browser.attach(retainedWebView)
            return retainedWebView
        }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true

        browser.attach(webView)
        let initialURL = browser.currentURL ?? url
        context.coordinator.lastRequestedURL = initialURL
        browser.load(initialURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastRequestedURL != url else { return }
        context.coordinator.lastRequestedURL = url
        guard webView.url != url else { return }
        browser.load(url)
        browser.refreshNavigationState()
    }

    func makeCoordinator() -> Coordinator { Coordinator(browser: browser) }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let browser: MediaWebBrowser
        var lastRequestedURL: URL?

        init(browser: MediaWebBrowser) {
            self.browser = browser
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            browser.isLoading = true
            browser.refreshNavigationState()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            browser.isLoading = false
            browser.navigationFinished(at: webView.url)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            browser.isLoading = false
            browser.refreshNavigationState()
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            browser.isLoading = false
            browser.refreshNavigationState()
        }
    }
}
