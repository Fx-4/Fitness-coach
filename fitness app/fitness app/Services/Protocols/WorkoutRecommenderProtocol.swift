import Foundation

// MARK: - Legacy recommender (fitness-level based, used by WorkoutsView)

protocol WorkoutRecommenderProtocol {
    func recommendations(for input: WorkoutProfileInput) -> [WorkoutRecommendation]
}

/// Input for the legacy fitness-level recommender
struct WorkoutProfileInput: Sendable {
    let fitnessLevel: FitnessLevel
    let recentSessionCount: Int
    let lastSessionCalories: Double?
    let lastSessionType: WorkoutType?
    let todayCaloriesBurned: Double
}

struct WorkoutRecommendation: Identifiable, Sendable {
    let id: UUID
    let type: WorkoutType
    let title: String
    let description: String
    let durationMinutes: Int
    let difficulty: WorkoutDifficulty
    let exercises: [ExerciseBlueprint]

    init(
        type: WorkoutType,
        title: String,
        description: String,
        durationMinutes: Int,
        difficulty: WorkoutDifficulty,
        exercises: [ExerciseBlueprint]
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.description = description
        self.durationMinutes = durationMinutes
        self.difficulty = difficulty
        self.exercises = exercises
    }
}

struct ExerciseBlueprint: Identifiable, Sendable {
    let id: UUID
    let name: String
    let muscleGroup: MuscleGroup
    let sets: Int
    let reps: Int
    let durationSeconds: Int
    let instructions: String

    init(
        name: String,
        muscleGroup: MuscleGroup,
        sets: Int = 3,
        reps: Int = 10,
        durationSeconds: Int = 0,
        instructions: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.reps = reps
        self.durationSeconds = durationSeconds
        self.instructions = instructions
    }
}

// MARK: - Lesson 9: New protocol-based recommendation system

protocol ExerciseCatalogProviding {
    func fetchCandidates(query: ExerciseSearchQuery) async throws -> [ExerciseTemplate]
}

protocol CalorieEstimating {
    func estimateCalories(
        activityName: String,
        weightPounds: Double?,
        durationMinutes: Int
    ) async throws -> CalorieEstimate
}

protocol WorkoutSafetyChecking {
    func validate(_ plan: WorkoutPlan, input: RecommendationInput) -> SafetyResult
}

protocol WorkoutRecommending {
    func recommendPlan(input: RecommendationInput) async throws -> WorkoutPlan
}
