import SwiftUI
import FirebaseCore

@main
struct fitness_appApp: App {

    @StateObject private var store = AppDataStore.shared

    init() {
        FirebaseApp.configure()   // reads GoogleService-Info.plist automatically
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .task { await requestHealthKitPermissions() }
        }
    }

    @MainActor
    private func requestHealthKitPermissions() async {
        try? await HealthKitService.shared.requestPermissions()
    }
}
