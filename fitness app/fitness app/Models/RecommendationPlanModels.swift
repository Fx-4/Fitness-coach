import Foundation

// MARK: - WorkoutIntensity (user preference input + plan output level)

enum WorkoutIntensity: String, Codable, CaseIterable, Identifiable {
    case light    = "Light"
    case moderate = "Moderate"
    case vigorous = "Vigorous"

    var id: String { rawValue }

    /// Conservative kcal/min estimate for a ~70 kg person
    var caloriesPerMinute: Double {
        switch self {
        case .light:    return 4.0   // brisk walk / gentle yoga
        case .moderate: return 7.5   // jog / bodyweight circuit
        case .vigorous: return 11.5  // HIIT / running
        }
    }

    /// Map to existing WorkoutDifficulty for backward compat
    var difficulty: WorkoutDifficulty {
        switch self {
        case .light:    return .easy
        case .moderate: return .moderate
        case .vigorous: return .hard
        }
    }

    var systemImage: String {
        switch self {
        case .light:    return "leaf.fill"
        case .moderate: return "flame.fill"
        case .vigorous: return "bolt.fill"
        }
    }
}

// MARK: - ExerciseType

enum ExerciseType: String, Codable, CaseIterable {
    case cardio       = "Cardio"
    case strength     = "Strength"
    case stretching   = "Stretching"
    case plyometrics  = "Plyometrics"
    case core         = "Core"

    var systemImage: String {
        switch self {
        case .cardio:      return "figure.run"
        case .strength:    return "dumbbell.fill"
        case .stretching:  return "figure.flexibility"
        case .plyometrics: return "bolt.heart.fill"
        case .core:        return "figure.core.training"
        }
    }
}

// MARK: - ExerciseTemplate  (normalized external model — external schemas stay here)

struct ExerciseTemplate: Identifiable {
    let id: String
    let name: String
    let type: ExerciseType
    let difficulty: WorkoutIntensity
    let primaryMuscle: String?
    let equipment: [String]
    let instructions: String
    let safetyInfo: String?
    let sourceProvider: String
    let caloriesPerMinute: Double    // used for calorie estimate
}

// MARK: - ExerciseBlock  (plan output — what the UI renders)

struct ExerciseBlock: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var sets: Int
    var reps: Int           // 0 = duration-based
    var durationSeconds: Int // 0 = rep-based
    var instructions: String
    var safetyNote: String?

    var displayRepsOrDuration: String {
        if reps > 0 { return "\(reps) reps" }
        if durationSeconds > 0 {
            let m = durationSeconds / 60
            let s = durationSeconds % 60
            return m > 0 ? "\(m)m \(s)s" : "\(s)s"
        }
        return "–"
    }
}

// MARK: - WorkoutPlan  (output of the recommendation engine)

struct WorkoutPlan: Identifiable {
    var id: UUID = UUID()
    var title: String
    var estimatedCalories: Double
    var durationMinutes: Int
    var intensity: WorkoutIntensity
    var exercises: [ExerciseBlock]
    var sourceProvider: String
    var safetyNotes: [String]

    var estimatedCaloriesFormatted: String {
        estimatedCalories.formatted(.number.precision(.fractionLength(0)))
    }
}

// MARK: - WorkoutSessionSummary  (lightweight history for recommendation input)

struct WorkoutSessionSummary: Codable {
    var date: Date
    var exerciseType: ExerciseType
    var durationMinutes: Int
    var estimatedCalories: Double
    var intensity: WorkoutIntensity
}

// MARK: - RecommendationInput  (per PDF Lesson 9 spec)

struct RecommendationInput {
    var targetCalories: Double
    var activeEnergyBurned: Double
    var availableMinutes: Int
    var preferredIntensity: WorkoutIntensity
    var bodyWeightPounds: Double?
    var recentSessions: [WorkoutSessionSummary]

    /// Calories still to burn to reach today's goal
    var remainingCalories: Double {
        max(0, targetCalories - activeEnergyBurned)
    }

    var goalAlreadyReached: Bool { remainingCalories <= 0 }
}

// MARK: - AI Coach Drafts

struct CoachScheduleDay: Identifiable, Codable {
    var id: UUID = UUID()
    var day: String
    var focus: String
    var durationMinutes: Int
    var intensity: WorkoutIntensity
    var exercises: [String]
    var note: String
}

struct CoachGoalDraft: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var dailyCalorieGoal: Int
    var weeklySessions: Int
    var sessionMinutes: Int
    var fitnessLevel: FitnessLevel
    var focus: String
}

struct CoachScheduleDraft: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var summary: String
    var goal: CoachGoalDraft
    var days: [CoachScheduleDay]
}

struct CoachScheduleResponse: Codable {
    var reply: String
    var draft: CoachScheduleDraft
}

extension CoachScheduleDay {
    static func blank(day: String = "Monday") -> CoachScheduleDay {
        CoachScheduleDay(
            day: day,
            focus: "Strength + mobility",
            durationMinutes: 45,
            intensity: .moderate,
            exercises: ["Squat", "Push-Up", "Plank"],
            note: "Keep the pace controlled and the form clean."
        )
    }
}

extension CoachScheduleDraft {
    static func blank() -> CoachScheduleDraft {
        CoachScheduleDraft(
            title: "New Weekly Schedule",
            summary: "A balanced plan you can refine before saving.",
            goal: CoachGoalDraft(
                title: "General fitness goal",
                summary: "A steady starting point that keeps things realistic.",
                dailyCalorieGoal: 500,
                weeklySessions: 4,
                sessionMinutes: 45,
                fitnessLevel: .beginner,
                focus: "general fitness"
            ),
            days: [
                .blank(day: "Monday"),
                .blank(day: "Wednesday"),
                .blank(day: "Friday")
            ]
        )
    }
}

// MARK: - ExerciseSearchQuery

struct ExerciseSearchQuery {
    var type: ExerciseType?
    var difficulty: WorkoutIntensity?
    var muscle: String?
    var limit: Int = 20
}

// MARK: - CalorieEstimate

struct CalorieEstimate {
    var activityName: String
    var durationMinutes: Int
    var totalCalories: Double
    var caloriesPerMinute: Double
}

// MARK: - SafetyResult

enum SafetyResult {
    case approved
    case approvedWithWarnings([String])
    case needsLowerIntensity
    case needsShorterDuration(Int)   // suggested max minutes
}
