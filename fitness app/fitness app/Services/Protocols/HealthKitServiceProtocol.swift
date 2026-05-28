import Foundation

protocol HealthKitServiceProtocol: AnyObject {
    var isAvailable: Bool { get }
    var activeEnergyToday: Double { get }
    var stepCountToday: Int { get }
    var restingHeartRate: Double? { get }
    func requestPermissions() async throws
    func fetchTodayActiveEnergy() async throws -> Double
    func fetchTodayStepCount() async throws -> Int
    func fetchWeeklyCalories() async throws -> [DailyCalorieSample]
}

struct DailyCalorieSample: Identifiable, Sendable {
    let id: UUID
    let date: Date
    let activeCalories: Double

    init(date: Date, activeCalories: Double) {
        self.id = UUID()
        self.date = date
        self.activeCalories = activeCalories
    }
}
