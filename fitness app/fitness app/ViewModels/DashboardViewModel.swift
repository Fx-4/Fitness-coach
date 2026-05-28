import SwiftUI
import HealthKit

// MARK: - Health permission state

enum HealthStatus: Equatable {
    case unavailable    // simulator / no Health app
    case notDetermined  // never asked
    case denied         // user said no
    case authorized     // good to go
}

// MARK: - ViewModel

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var activeEnergyToday: Double = 0
    @Published var stepCountToday: Int = 0
    @Published var weeklyCalories: [DailyCalorieSample] = []
    @Published var isLoadingHealth = false
    @Published var healthError: String? = nil
    @Published var dailyCalorieGoal: Int = 500
    @Published var healthStatus: HealthStatus = .unavailable

    private let healthKit: HealthKitServiceProtocol

    init(healthKit: HealthKitServiceProtocol = HealthKitService.shared) {
        self.healthKit = healthKit
        healthStatus = resolvedStatus()
    }

    // MARK: - Computed

    var activeEnergyProgress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(activeEnergyToday / Double(dailyCalorieGoal), 1.0)
    }

    var activeEnergyFormatted: String {
        activeEnergyToday.formatted(.number.precision(.fractionLength(0)))
    }

    var goalFormatted: String { dailyCalorieGoal.formatted() }

    var stepCountFormatted: String { stepCountToday.formatted() }

    // MARK: - Public

    func requestPermission() async {
        guard healthKit.isAvailable else { return }
        try? await healthKit.requestPermissions()
        // HealthKit does not expose read-authorization status (privacy by design).
        // Treat completion of the permission dialog as "authorized".
        UserDefaults.standard.set(true, forKey: "fitcoach.hk.authorized")
        healthStatus = .authorized
        await loadHealthData()
    }

    func loadHealthData() async {
        // Lesson Goal 2 (read today's active energy)
        guard healthKit.isAvailable else {
            loadMockData()   // simulator: show sample data
            return
        }
        guard healthStatus == .authorized else { return }

        isLoadingHealth = true
        healthError = nil
        defer { isLoadingHealth = false }

        do {
            async let energy = healthKit.fetchTodayActiveEnergy()
            async let steps  = healthKit.fetchTodayStepCount()
            async let weekly = healthKit.fetchWeeklyCalories()
            activeEnergyToday = try await energy
            stepCountToday    = try await steps
            weeklyCalories    = try await weekly
        } catch {
            healthError = "Could not load health data. Pull to refresh."
        }
    }

    func updateGoal(from profile: UserProfile) {
        dailyCalorieGoal = profile.dailyCalorieGoal
    }

    // MARK: - Private

    /// Mock data shown on simulator so the UI is never empty during development
    private func loadMockData() {
        activeEnergyToday = 312
        stepCountToday    = 6_480
        let today = Date()
        weeklyCalories = (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: today) ?? today
            return DailyCalorieSample(date: date, activeCalories: Double.random(in: 200...650))
        }.reversed()
    }

    private func resolvedStatus() -> HealthStatus {
        guard healthKit.isAvailable else { return .unavailable }
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        // authorizationStatus always returns .sharingDenied for read-only types (HealthKit privacy design).
        // Use UserDefaults to remember whether the user completed the permission flow.
        if UserDefaults.standard.bool(forKey: "fitcoach.hk.authorized") { return .authorized }
        return .notDetermined
    }
}
