import Foundation

struct UserProfile: Codable {
    var name: String = ""
    var age: Int = 25
    var weightKg: Double = 70.0
    var heightCm: Double = 170.0
    var dailyCalorieGoal: Int = 500
    var fitnessLevel: FitnessLevel = .beginner

    var bmr: Double {
        (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + 5
    }

    var bmi: Double {
        let heightM = heightCm / 100
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }
}

enum FitnessLevel: String, Codable, CaseIterable {
    case beginner     = "Beginner"
    case intermediate = "Intermediate"
    case advanced     = "Advanced"

    var activityMultiplier: Double {
        switch self {
        case .beginner:     return 1.375
        case .intermediate: return 1.55
        case .advanced:     return 1.725
        }
    }
}
