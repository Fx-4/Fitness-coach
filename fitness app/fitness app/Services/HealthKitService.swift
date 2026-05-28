import Foundation
import HealthKit

/// Bridges HealthKit callback APIs to async/await.
final class HealthKitService: HealthKitServiceProtocol {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private(set) var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    private(set) var activeEnergyToday: Double = 0
    private(set) var stepCountToday: Int = 0
    private(set) var restingHeartRate: Double? = nil

    private let readTypes: Set<HKQuantityType> = [
        HKQuantityType(.activeEnergyBurned),
        HKQuantityType(.stepCount),
        HKQuantityType(.restingHeartRate)
    ]

    private init() {}

    func requestPermissions() async throws {
        guard isAvailable else { return }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchTodayActiveEnergy() async throws -> Double {
        guard isAvailable else { return 0 }
        let value = try await fetchSum(
            type: HKQuantityType(.activeEnergyBurned),
            unit: .kilocalorie(),
            predicate: todayPredicate()
        )
        activeEnergyToday = value
        return value
    }

    func fetchTodayStepCount() async throws -> Int {
        guard isAvailable else { return 0 }
        let value = try await fetchSum(
            type: HKQuantityType(.stepCount),
            unit: .count(),
            predicate: todayPredicate()
        )
        let steps = Int(value)
        stepCountToday = steps
        return steps
    }

    func fetchWeeklyCalories() async throws -> [DailyCalorieSample] {
        guard isAvailable else { return [] }
        let calendar = Calendar.current
        let endDate = Date.now
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else { return [] }
        let predicate = HKQuery.predicateForSamples(
            withStart: calendar.startOfDay(for: startDate),
            end: endDate
        )
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(.activeEnergyBurned),
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: calendar.startOfDay(for: endDate),
                intervalComponents: DateComponents(day: 1)
            )
            query.initialResultsHandler = { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                var samples: [DailyCalorieSample] = []
                results?.enumerateStatistics(from: startDate, to: endDate) { stats, _ in
                    let cal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                    samples.append(DailyCalorieSample(date: stats.startDate, activeCalories: cal))
                }
                continuation.resume(returning: samples)
            }
            store.execute(query)
        }
    }

    // MARK: - Private

    private func fetchSum(
        type: HKQuantityType,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> Double {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let value = stats?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    private func todayPredicate() -> NSPredicate {
        let start = Calendar.current.startOfDay(for: .now)
        return HKQuery.predicateForSamples(withStart: start, end: .now)
    }
}
