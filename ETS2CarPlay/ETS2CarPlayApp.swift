import SwiftUI
import SwiftData

@main
struct ETS2CarPlayApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: TripRecord.self)
    }
}
