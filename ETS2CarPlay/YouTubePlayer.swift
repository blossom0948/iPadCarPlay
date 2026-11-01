import SwiftUI
import WebKit

struct YouTubeScreen: View {
    @State private var input = ""
    @State private var videoID: String?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("YouTube")
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                    Text("공식 임베드 플레이어")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.64))
                }
                Spacer()
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.red)
            }

            HStack(spacing: 10) {
                TextField("YouTube URL 또는 동영상 ID", text: $input)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 15)
                    .frame(height: 48)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 15))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .onSubmit(loadVideo)
                Button(action: loadVideo) {
                    Label("열기", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 18)
                        .frame(height: 48)
                        .background(Color.red.opacity(0.84), in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.orange)
            }

            Group {
                if let videoID {
                    OfficialYouTubeWebView(videoID: videoID)
                        .frame(minWidth: 200, minHeight: 200)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    ContentUnavailableView {
                        Label("동영상을 선택하세요", systemImage: "play.rectangle")
                    } description: {
                        Text("실제 동영상 URL이나 ID를 입력하면 YouTube 공식 플레이어가 열립니다.")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 24))
                }
            }

            Text("영상은 YouTube 플레이어 안에서 재생됩니다. YouTube의 재생 버튼과 광고, 브랜드 표시가 유지됩니다.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
        }
    }

    private func loadVideo() {
        guard let id = YouTubeVideoIdentifier.parse(input) else {
            errorMessage = "올바른 YouTube 동영상 주소 또는 ID를 입력해 주세요."
            videoID = nil
            return
        }
        errorMessage = nil
        videoID = id
    }
}

private struct OfficialYouTubeWebView: UIViewRepresentable {
    let videoID: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [.audio, .video]
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let html = """
        <!doctype html>
        <html><head><meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"></head>
        <body style="margin:0;background:#000;overflow:hidden">
        <iframe width="100%" height="100%" src="https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&controls=1"
          title="YouTube video player" frameborder="0"
          allow="accelerometer; encrypted-media; gyroscope; picture-in-picture; web-share"
          referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
        </body></html>
        """
        if webView.url == nil || context.coordinator.loadedID != videoID {
            context.coordinator.loadedID = videoID
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var loadedID: String?
    }
}

private enum YouTubeVideoIdentifier {
    static func parse(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidID(value) { return value }
        guard let components = URLComponents(string: value), let host = components.host?.lowercased() else { return nil }
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            let id = components.path.split(separator: "/").first.map(String.init)
            return id.flatMap { isValidID($0) ? $0 : nil }
        }
        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else { return nil }
        if let id = components.queryItems?.first(where: { $0.name == "v" })?.value, isValidID(id) { return id }
        let parts = components.path.split(separator: "/").map(String.init)
        if let index = parts.firstIndex(where: { ["embed", "shorts", "live"].contains($0) }), parts.indices.contains(index + 1) {
            let id = parts[index + 1]
            return isValidID(id) ? id : nil
        }
        return nil
    }

    private static func isValidID(_ value: String) -> Bool {
        value.range(of: #"^[A-Za-z0-9_-]{11}$"#, options: .regularExpression) != nil
    }
}
