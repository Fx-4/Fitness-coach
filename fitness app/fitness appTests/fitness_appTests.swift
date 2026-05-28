import XCTest
@testable import fitness_app

// MARK: - DashboardViewModel Tests

final class DashboardViewModelTests: XCTestCase {

    func testProgressZeroWhenNoBurn() async throws {
        let mock = MockHealthKitService()
        mock.activeEnergyToday = 0
        let vm = await DashboardViewModel(healthKit: mock)
        await MainActor.run { vm.dailyCalorieGoal = 500 }
        let progress = await MainActor.run { vm.activeEnergyProgress }
        XCTAssertEqual(progress, 0)
    }

    func testProgressClampedAtGoal() async throws {
        let mock = MockHealthKitService()
        mock.activeEnergyToday = 800
        let vm = await DashboardViewModel(healthKit: mock)
        await MainActor.run { vm.dailyCalorieGoal = 500 }
        await vm.loadHealthData()
        let progress = await MainActor.run { vm.activeEnergyProgress }
        XCTAssertEqual(progress, 1.0)
    }

    func testProgressFractional() async throws {
        let mock = MockHealthKitService()
        mock.activeEnergyToday = 250
        let vm = await DashboardViewModel(healthKit: mock)
        await MainActor.run { vm.dailyCalorieGoal = 500 }
        await vm.loadHealthData()
        let progress = await MainActor.run { vm.activeEnergyProgress }
        XCTAssertEqual(progress, 0.5, accuracy: 0.001)
    }

    func testUnavailableHealthKit() async throws {
        let mock = MockHealthKitService()
        mock.isAvailable = false
        let vm = await DashboardViewModel(healthKit: mock)
        await vm.loadHealthData()
        let (energy, error) = await MainActor.run { (vm.activeEnergyToday, vm.healthError) }
        XCTAssertEqual(energy, 0)
        XCTAssertNil(error)
    }

    func testHealthKitErrorSurfacesMessage() async throws {
        let mock = MockHealthKitService()
        mock.shouldThrow = true
        let vm = await DashboardViewModel(healthKit: mock)
        await vm.loadHealthData()
        let error = await MainActor.run { vm.healthError }
        XCTAssertNotNil(error)
    }

    func testUpdateGoalFromProfile() async throws {
        let mock = MockHealthKitService()
        let vm = await DashboardViewModel(healthKit: mock)
        var profile = UserProfile()
        profile.dailyCalorieGoal = 750
        let profileSnapshot = profile
        await MainActor.run { vm.updateGoal(from: profileSnapshot) }
        let goal = await MainActor.run { vm.dailyCalorieGoal }
        XCTAssertEqual(goal, 750)
    }
}

// MARK: - WorkoutRecommender Tests

final class WorkoutRecommenderTests: XCTestCase {
    private let recommender = WorkoutRecommender.shared

    func testBeginnerGetThreeRecommendations() {
        let input = WorkoutProfileInput(
            fitnessLevel: .beginner,
            recentSessionCount: 2,
            lastSessionCalories: nil,
            lastSessionType: nil,
            todayCaloriesBurned: 0
        )
        let recs = recommender.recommendations(for: input)
        XCTAssertEqual(recs.count, 3)
    }

    func testRecoveryAfterHighCalories() {
        let input = WorkoutProfileInput(
            fitnessLevel: .intermediate,
            recentSessionCount: 5,
            lastSessionCalories: 700,
            lastSessionType: .hiit,
            todayCaloriesBurned: 700
        )
        let recs = recommender.recommendations(for: input)
        XCTAssertEqual(recs.count, 1)
        XCTAssertEqual(recs.first?.type, .recovery)
    }

    func testNoRecoveryBelowThreshold() {
        let input = WorkoutProfileInput(
            fitnessLevel: .intermediate,
            recentSessionCount: 3,
            lastSessionCalories: 400,
            lastSessionType: .strength,
            todayCaloriesBurned: 400
        )
        let recs = recommender.recommendations(for: input)
        XCTAssertNotEqual(recs.first?.type, .recovery)
    }

    func testAdvancedGetsHardDifficulty() {
        let input = WorkoutProfileInput(
            fitnessLevel: .advanced,
            recentSessionCount: 6,
            lastSessionCalories: 300,
            lastSessionType: .cardio,
            todayCaloriesBurned: 300
        )
        let recs = recommender.recommendations(for: input)
        XCTAssertTrue(recs.contains { $0.difficulty == .hard })
    }

    func testAllRecommendationsHaveExercises() {
        let input = WorkoutProfileInput(
            fitnessLevel: .intermediate,
            recentSessionCount: 3,
            lastSessionCalories: 200,
            lastSessionType: nil,
            todayCaloriesBurned: 200
        )
        let recs = recommender.recommendations(for: input)
        XCTAssertTrue(recs.allSatisfy { !$0.exercises.isEmpty })
    }

    func testAllRecommendationsHavePositiveDuration() {
        for level in FitnessLevel.allCases {
            let input = WorkoutProfileInput(
                fitnessLevel: level,
                recentSessionCount: 2,
                lastSessionCalories: nil,
                lastSessionType: nil,
                todayCaloriesBurned: 0
            )
            let recs = recommender.recommendations(for: input)
            XCTAssertTrue(recs.allSatisfy { $0.durationMinutes > 0 })
        }
    }
}

// MARK: - WorkoutViewModel Tests

final class WorkoutViewModelTests: XCTestCase {

    func testElapsedFormatsAsMMSS() async throws {
        let vm = await WorkoutViewModel()
        await MainActor.run { vm.elapsedSeconds = 125 }
        let formatted = await MainActor.run { vm.elapsedFormatted }
        XCTAssertEqual(formatted, "02:05")
    }
}

// MARK: - ProfileViewModel Tests

final class ProfileViewModelTests: XCTestCase {

    func testBMICalculatesCorrectly() async throws {
        let vm = await ProfileViewModel()
        await MainActor.run {
            vm.weightKg = 70
            vm.heightCm = 170
        }
        let bmi = await MainActor.run { vm.bmiFormatted }
        let expected = (70.0 / (1.70 * 1.70)).formatted(.number.precision(.fractionLength(1)))
        XCTAssertEqual(bmi, expected)
    }

    func testLoadCopiesAllFields() async throws {
        let vm = await ProfileViewModel()
        var profile = UserProfile()
        profile.name             = "Alex"
        profile.age              = 30
        profile.weightKg         = 80
        profile.heightCm         = 180
        profile.dailyCalorieGoal = 600
        profile.fitnessLevel     = .advanced
        let profileSnapshot = profile
        await MainActor.run { vm.load(from: profileSnapshot) }
        let (name, age, weight, height, goal, level) = await MainActor.run {
            (vm.name, vm.age, vm.weightKg, vm.heightCm, vm.dailyCalorieGoal, vm.fitnessLevel)
        }
        XCTAssertEqual(name, "Alex")
        XCTAssertEqual(age, 30)
        XCTAssertEqual(weight, 80)
        XCTAssertEqual(height, 180)
        XCTAssertEqual(goal, 600)
        XCTAssertEqual(level, .advanced)
    }
}
