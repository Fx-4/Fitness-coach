import SwiftUI
import FirebaseCore

@main
struct fitness_appApp: App {

    @StateObject private var store   = AppDataStore.shared
    @StateObject private var authVM  = AuthViewModel()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(authVM)
                .task { await requestHealthKitPermissions() }
        }
    }

    @MainActor
    private func requestHealthKitPermissions() async {
        try? await HealthKitService.shared.requestPermissions()
    }
}
