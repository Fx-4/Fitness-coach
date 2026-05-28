import SwiftUI

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var age: Int = 25
    @Published var weightKg: Double = 70
    @Published var heightCm: Double = 170
    @Published var dailyCalorieGoal: Int = 500
    @Published var fitnessLevel: FitnessLevel = .beginner
    @Published var isSaved = false

    func load(from profile: UserProfile) {
        name             = profile.name
        age              = profile.age
        weightKg         = profile.weightKg
        heightCm         = profile.heightCm
        dailyCalorieGoal = profile.dailyCalorieGoal
        fitnessLevel     = profile.fitnessLevel
    }

    func save(to store: AppDataStore) {
        store.profile.name             = name
        store.profile.age              = age
        store.profile.weightKg         = weightKg
        store.profile.heightCm         = heightCm
        store.profile.dailyCalorieGoal = dailyCalorieGoal
        store.profile.fitnessLevel     = fitnessLevel
        isSaved = true
    }

    var bmiFormatted: String {
        let heightM = heightCm / 100
        guard heightM > 0 else { return "—" }
        let bmi = weightKg / (heightM * heightM)
        return bmi.formatted(.number.precision(.fractionLength(1)))
    }

    var tdeeFormatted: String {
        let bmr  = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
        let tdee = bmr * fitnessLevel.activityMultiplier
        return tdee.formatted(.number.precision(.fractionLength(0)))
    }
}
