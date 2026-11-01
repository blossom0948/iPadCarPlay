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
