import Combine
import Foundation

struct PublishedAppRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL?
    let prerelease: Bool
    let draft: Bool

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case prerelease
        case draft
    }
}

@MainActor
final class AppUpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case current
        case available(version: String, notes: String)
        case noPublishedRelease
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCheckedAt: Date?

    let currentVersion: String

    private let releaseURL = URL(string: "https://api.github.com/repos/blossom0948/iPadCarPlay/releases/latest")!
    private let lastCheckKey = "appUpdate.lastCheck.v1"

    init(bundle: Bundle = .main) {
        currentVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        lastCheckedAt = UserDefaults.standard.object(forKey: lastCheckKey) as? Date
    }

    func checkIfNeeded() async {
        await checkNow()
    }

    func checkNow() async {
        state = .checking
        var request = URLRequest(url: releaseURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ETS2CarPlay-iPad", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                state = .failed("GitHub 응답을 확인할 수 없습니다.")
                return
            }
            lastCheckedAt = .now
            UserDefaults.standard.set(lastCheckedAt, forKey: lastCheckKey)

            if response.statusCode == 404 {
                state = .noPublishedRelease
                return
            }
            guard (200...299).contains(response.statusCode) else {
                state = .failed("업데이트 서버가 HTTP \(response.statusCode) 응답을 보냈습니다.")
                return
            }

            let release = try JSONDecoder().decode(PublishedAppRelease.self, from: data)
            guard !release.draft, !release.prerelease else {
                state = .noPublishedRelease
                return
            }
            guard Self.isNewer(release.tagName, than: currentVersion) else {
                state = .current
                return
            }
            let releaseName = release.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            state = .available(
                version: releaseName.isEmpty ? release.tagName : releaseName,
                notes: release.body?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            )
        } catch {
            state = .failed("업데이트 정보를 불러오지 못했습니다. 인터넷 연결을 확인해 주세요.")
        }
    }

    private static func isNewer(_ remote: String, than installed: String) -> Bool {
        func components(_ value: String) -> [Int]? {
            let stripped = value.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let parts = stripped.split(separator: ".", omittingEmptySubsequences: false)
            guard !parts.isEmpty else { return nil }
            let numbers = parts.map { part -> Int? in
                let numericPrefix = part.prefix { $0.isNumber }
                return numericPrefix.isEmpty ? nil : Int(numericPrefix)
            }
            guard numbers.allSatisfy({ $0 != nil }) else { return nil }
            return numbers.compactMap { $0 }
        }

        guard let remoteParts = components(remote), let installedParts = components(installed) else { return false }
        let count = max(remoteParts.count, installedParts.count)
        for index in 0..<count {
            let newValue = index < remoteParts.count ? remoteParts[index] : 0
            let oldValue = index < installedParts.count ? installedParts[index] : 0
            if newValue != oldValue { return newValue > oldValue }
        }
        return false
    }
}
