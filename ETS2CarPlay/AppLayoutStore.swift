import Combine
import Foundation
import SwiftUI

@MainActor
final class AppLayoutStore: ObservableObject {
    @Published private(set) var orderedSections: [AppSection]
    @Published private(set) var hiddenSections: Set<AppSection>

    private let orderKey = "ets2.launcher.order.v1"
    private let hiddenKey = "ets2.launcher.hidden.v1"

    init() {
        let defaults = AppSection.launcherItems
        let previousDefaultOrder: [AppSection] = [
            .phone, .music, .navigation, .messages, .dashboard, .voice, .youtube, .stats, .controls, .settings
        ]
        if let data = UserDefaults.standard.data(forKey: orderKey),
           let rawOrder = try? JSONDecoder().decode([String].self, from: data) {
            let saved = rawOrder.compactMap(AppSection.init(rawValue:)).filter { defaults.contains($0) }
            if saved == previousDefaultOrder {
                orderedSections = defaults
                if let migratedData = try? JSONEncoder().encode(defaults.map(\.rawValue)) {
                    UserDefaults.standard.set(migratedData, forKey: orderKey)
                }
            } else {
                orderedSections = saved + defaults.filter { !saved.contains($0) }
            }
        } else {
            orderedSections = defaults
        }
        if let data = UserDefaults.standard.data(forKey: hiddenKey),
           let rawHidden = try? JSONDecoder().decode([String].self, from: data) {
            hiddenSections = Set(rawHidden.compactMap(AppSection.init(rawValue:)))
        } else {
            hiddenSections = []
        }
    }

    var visibleSections: [AppSection] { orderedSections.filter { !hiddenSections.contains($0) } }

    func move(from source: IndexSet, to destination: Int) {
        orderedSections.move(fromOffsets: source, toOffset: destination)
        saveOrder()
    }

    func setVisible(_ visible: Bool, for section: AppSection) {
        if visible { hiddenSections.remove(section) }
        else { hiddenSections.insert(section) }
        saveHidden()
    }

    private func saveOrder() {
        guard let data = try? JSONEncoder().encode(orderedSections.map(\.rawValue)) else { return }
        UserDefaults.standard.set(data, forKey: orderKey)
    }

    private func saveHidden() {
        guard let data = try? JSONEncoder().encode(hiddenSections.map(\.rawValue).sorted()) else { return }
        UserDefaults.standard.set(data, forKey: hiddenKey)
    }
}

struct SplitPair: Codable, Equatable, Hashable, Identifiable {
    let primary: AppSection
    let media: YouTubeService

    var id: String { "\(primary.rawValue)-\(media.rawValue)" }

    var title: String {
        "\(primary.launcherTitle) + \(media.appSection.launcherTitle)"
    }
}

@MainActor
final class SplitShortcutStore: ObservableObject {
    @Published private(set) var recent: SplitPair?
    @Published private(set) var favorites: [SplitPair]

    private let recentKey = "ets2.split.recent.v1"
    private let favoritesKey = "ets2.split.favorites.v1"

    init() {
        recent = Self.load(SplitPair.self, key: recentKey)
        favorites = Self.load([SplitPair].self, key: favoritesKey) ?? []
    }

    func remember(_ pair: SplitPair) {
        recent = pair
        Self.save(pair, key: recentKey)
    }

    func toggleFavorite(_ pair: SplitPair) {
        if favorites.contains(pair) {
            favorites.removeAll { $0 == pair }
        } else {
            favorites.insert(pair, at: 0)
        }
        Self.save(favorites, key: favoritesKey)
    }

    func isFavorite(_ pair: SplitPair) -> Bool {
        favorites.contains(pair)
    }

    private static func load<Value: Decodable>(_ type: Value.Type, key: String) -> Value? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private static func save<Value: Encodable>(_ value: Value, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
