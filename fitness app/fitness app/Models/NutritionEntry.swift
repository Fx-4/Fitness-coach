import Foundation

struct NutritionEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var loggedAt: Date = Date()
    var mealName: String = ""
    var calories: Int = 0
    var proteinG: Double = 0.0
    var carbsG: Double = 0.0
    var fatG: Double = 0.0
    var mealType: MealType = .snack
}

enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast   = "Breakfast"
    case lunch       = "Lunch"
    case dinner      = "Dinner"
    case snack       = "Snack"
    case preworkout  = "Pre-Workout"
    case postworkout = "Post-Workout"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .breakfast:   return "sunrise.fill"
        case .lunch:       return "sun.max.fill"
        case .dinner:      return "moon.fill"
        case .snack:       return "fork.knife"
        case .preworkout:  return "bolt.fill"
        case .postworkout: return "checkmark.seal.fill"
        }
    }
}
