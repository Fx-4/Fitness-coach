import Foundation

/// Injected in unit tests — never hits the real HealthKit store.
final class MockHealthKitService: HealthKitServiceProtocol {
    var isAvailable: Bool = true
    var activeEnergyToday: Double = 320
    var stepCountToday: Int = 6500
    var restingHeartRate: Double? = 62

    var permissionsRequested = false
    var shouldThrow = false

    func requestPermissions() async throws {
        if shouldThrow { throw MockError.forced }
        permissionsRequested = true
    }

    func fetchTodayActiveEnergy() async throws -> Double {
        if shouldThrow { throw MockError.forced }
        return activeEnergyToday
    }

    func fetchTodayStepCount() async throws -> Int {
        if shouldThrow { throw MockError.forced }
        return stepCountToday
    }

    func fetchWeeklyCalories() async throws -> [DailyCalorieSample] {
        if shouldThrow { throw MockError.forced }
        let base = Date.now
        return (0..<7).map { offset in
            let date = Calendar.current.date(byAdding: .day, value: -offset, to: base) ?? base
            return DailyCalorieSample(date: date, activeCalories: Double.random(in: 200...600))
        }
    }

    enum MockError: Error { case forced }
}
