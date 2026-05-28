import Foundation

struct WorkoutSession: Codable, Identifiable {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    var completedAt: Date? = nil
    var workoutType: WorkoutType = .strength
    var activeCaloriesBurned: Double = 0.0
    var durationSeconds: Int = 0
    var notes: String = ""
    var difficulty: WorkoutDifficulty = .moderate
    var isCompleted: Bool = false
    var exerciseSets: [ExerciseSet] = []

    var durationFormatted: String {
        let m = durationSeconds / 60
        let s = durationSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case strength  = "Strength"
    case cardio    = "Cardio"
    case hiit      = "HIIT"
    case yoga      = "Yoga"
    case mobility  = "Mobility"
    case recovery  = "Recovery"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .strength: return "dumbbell.fill"
        case .cardio:   return "figure.run"
        case .hiit:     return "bolt.heart.fill"
        case .yoga:     return "figure.mind.and.body"
        case .mobility: return "figure.flexibility"
        case .recovery: return "bed.double.fill"
        }
    }
}

enum WorkoutDifficulty: String, Codable, CaseIterable {
    case easy     = "Easy"
    case moderate = "Moderate"
    case hard     = "Hard"
}
