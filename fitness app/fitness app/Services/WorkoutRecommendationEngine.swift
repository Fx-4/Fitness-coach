import Foundation

// MARK: - Workout Recommendation Engine  (HealthyAgent — Lab Part 2)
// Rule-based engine. External provider supplies candidates.
// The app scores and filters them. No health data sent externally.
//
// Scoring formula (from Lesson 9 spec):
//   score = calorieFit * 0.45
//         + durationFit * 0.20
//         + intensityFit * 0.20
//         + noveltyFit  * 0.10
//         + equipmentFit * 0.05
//         - safetyPenalty

final class WorkoutRecommendationEngine: WorkoutRecommending {
    static let shared = WorkoutRecommendationEngine()

    private let catalog: ExerciseCatalogProviding
    private let estimator: CalorieEstimating
    private let safetyPolicy: WorkoutSafetyPolicy

    init(
        catalog: ExerciseCatalogProviding = MockExerciseCatalogProvider(),
        estimator: CalorieEstimating = MockCalorieEstimator(),
        safetyPolicy: WorkoutSafetyPolicy = WorkoutSafetyPolicy()
    ) {
        self.catalog = catalog
        self.estimator = estimator
        self.safetyPolicy = safetyPolicy
    }

    // MARK: - WorkoutRecommending

    func recommendPlan(input: RecommendationInput) async throws -> WorkoutPlan {

        // Step 1 — determine search intent
        let query = buildQuery(for: input)

        // Step 2 — fetch candidates (fallback to built-in if provider fails)
        let candidates: [ExerciseTemplate]
        do {
            candidates = try await catalog.fetchCandidates(query: query)
        } catch {
            candidates = MockExerciseCatalogProvider.fallbackExercises
        }

        guard !candidates.isEmpty else {
            return fallbackMobilityPlan(input: input)
        }

        // Step 3 — score every candidate
        let scored = candidates
            .map { ex -> (ExerciseTemplate, Double) in
                (ex, score(exercise: ex, input: input))
            }
            .sorted { $0.1 > $1.1 }

        // Step 4 — select exercises to fill the session
        let selected = selectExercises(from: scored.map { $0.0 }, input: input)

        // Step 5 — estimate total calories for the session
        let totalCalories = await estimateTotalCalories(
            exercises: selected,
            input: input
        )

        // Step 6 — build plan
        var plan = buildPlan(
            title: planTitle(for: input),
            exercises: selected,
            calories: totalCalories,
            input: input
        )

        // Step 7 — safety check and apply guardrails
        let safetyResult = safetyPolicy.validate(plan, input: input)
        safetyPolicy.apply(safetyResult, to: &plan, input: input)

        return plan
    }

    // MARK: - Query building

    private func buildQuery(for input: RecommendationInput) -> ExerciseSearchQuery {
        if input.goalAlreadyReached {
            // Goal reached → suggest stretching / mobility only
            return ExerciseSearchQuery(type: .stretching, difficulty: .light, limit: 6)
        }

        // Map intensity to exercise types for variety
        let type: ExerciseType?
        switch input.preferredIntensity {
        case .light:    type = Bool.random() ? .cardio : .stretching
        case .moderate: type = Bool.random() ? .strength : .cardio
        case .vigorous: type = Bool.random() ? .plyometrics : .cardio
        }

        return ExerciseSearchQuery(
            type: type,
            difficulty: input.preferredIntensity,
            limit: 20
        )
    }

    // MARK: - Scoring

    private func score(exercise: ExerciseTemplate, input: RecommendationInput) -> Double {
        let estimated = exercise.caloriesPerMinute * Double(input.availableMinutes)
        let remaining = max(input.remainingCalories, 1)

        // calorieFit: prefer exercises whose calorie output is close to remaining gap
        let calorieFit: Double = {
            if input.goalAlreadyReached { return 1.0 }
            let diff = abs(estimated - remaining)
            return max(0.0, 1.0 - diff / remaining)
        }()

        // durationFit: exercises that fit the available time score better
        let durationFit: Double = input.availableMinutes >= 15 ? 1.0 : 0.6

        // intensityFit: exact match = 1.0, adjacent = 0.6, opposite = 0.2
        let intensityFit: Double = {
            switch (exercise.difficulty, input.preferredIntensity) {
            case (.light, .light), (.moderate, .moderate), (.vigorous, .vigorous):
                return 1.0
            case (.light, .moderate), (.moderate, .light),
                 (.moderate, .vigorous), (.vigorous, .moderate):
                return 0.6
            default:
                return 0.2
            }
        }()

        // noveltyFit: avoid repeating the same exercise type as recent sessions
        let noveltyFit: Double = {
            let recentTypes = input.recentSessions.map { $0.exerciseType }
            let count = recentTypes.filter { $0 == exercise.type }.count
            if count == 0 { return 1.0 }
            if count == 1 { return 0.7 }
            return 0.3
        }()

        // equipmentFit: bodyweight or minimal equipment preferred
        let equipmentFit: Double = {
            let isBodyweight = exercise.equipment.isEmpty
                || exercise.equipment.contains("body weight")
            return isBodyweight ? 1.0 : 0.8
        }()

        // safetyPenalty: down-rate very high intensity when user picked light
        let safetyPenalty: Double = {
            if exercise.difficulty == .vigorous && input.preferredIntensity == .light {
                return 0.3
            }
            return 0.0
        }()

        let raw = calorieFit   * 0.45
                + durationFit  * 0.20
                + intensityFit * 0.20
                + noveltyFit   * 0.10
                + equipmentFit * 0.05
                - safetyPenalty

        return max(0, raw)
    }

    // MARK: - Exercise selection

    private func selectExercises(
        from sorted: [ExerciseTemplate],
        input: RecommendationInput
    ) -> [ExerciseTemplate] {
        var selected: [ExerciseTemplate] = []
        var usedIds = Set<String>()

        // Warm-up for sessions >= 20 min (safety: always warm up)
        if input.availableMinutes >= 20 {
            if let warmup = MockExerciseCatalogProvider.catalog
                .first(where: { $0.type == .stretching && $0.difficulty == .light }) {
                selected.append(warmup)
                usedIds.insert(warmup.id)
            }
        }

        // Main block: up to 3 exercises from top-scored
        for ex in sorted where !usedIds.contains(ex.id) {
            guard selected.count < 4 else { break }
            selected.append(ex)
            usedIds.insert(ex.id)
        }

        // Cooldown for sessions >= 30 min
        if input.availableMinutes >= 30 {
            if let cooldown = MockExerciseCatalogProvider.catalog
                .first(where: { $0.type == .stretching && !usedIds.contains($0.id) }) {
                selected.append(cooldown)
            }
        }

        return selected
    }

    // MARK: - Calorie estimation

    private func estimateTotalCalories(
        exercises: [ExerciseTemplate],
        input: RecommendationInput
    ) async -> Double {
        // Distribute available time across exercises
        let perExerciseMinutes = max(1, input.availableMinutes / max(1, exercises.count))
        var total = 0.0
        for ex in exercises {
            if let est = try? await estimator.estimateCalories(
                activityName: ex.name,
                weightPounds: input.bodyWeightPounds,
                durationMinutes: perExerciseMinutes
            ) {
                total += est.totalCalories
            } else {
                total += ex.caloriesPerMinute * Double(perExerciseMinutes)
            }
        }
        // Conservative: cap at 120% of remaining to avoid over-promising
        let cap = max(input.remainingCalories * 1.2, 50)
        return min(total, cap)
    }

    // MARK: - Plan assembly

    private func buildPlan(
        title: String,
        exercises: [ExerciseTemplate],
        calories: Double,
        input: RecommendationInput
    ) -> WorkoutPlan {
        let blocks = exercises.map { ex -> ExerciseBlock in
            let minutes = max(1, input.availableMinutes / max(1, exercises.count))
            let isTimed = ex.type == .stretching || ex.type == .cardio
            return ExerciseBlock(
                name: ex.name,
                sets: isTimed ? 1 : 3,
                reps: isTimed ? 0 : 12,
                durationSeconds: isTimed ? minutes * 60 : 0,
                instructions: ex.instructions,
                safetyNote: ex.safetyInfo
            )
        }

        return WorkoutPlan(
            title: title,
            estimatedCalories: calories,
            durationMinutes: input.availableMinutes,
            intensity: input.preferredIntensity,
            exercises: blocks,
            sourceProvider: "FitCoach",
            safetyNotes: []  // filled by safety policy
        )
    }

    private func planTitle(for input: RecommendationInput) -> String {
        if input.goalAlreadyReached { return "Active Recovery & Mobility" }
        switch input.preferredIntensity {
        case .light:    return "Gentle \(input.availableMinutes)-Minute Session"
        case .moderate: return "\(input.availableMinutes)-Minute Moderate Circuit"
        case .vigorous: return "High-Intensity \(input.availableMinutes)-Min Blast"
        }
    }

    // MARK: - Fallback

    private func fallbackMobilityPlan(input: RecommendationInput) -> WorkoutPlan {
        let blocks = [
            ExerciseBlock(
                name: "High Knee March", sets: 1, reps: 0, durationSeconds: 120,
                instructions: "March in place, drive knees to hip height.",
                safetyNote: nil
            ),
            ExerciseBlock(
                name: "Child's Pose", sets: 1, reps: 0, durationSeconds: 60,
                instructions: "Sink hips to heels, arms extended. Breathe.",
                safetyNote: nil
            ),
        ]
        return WorkoutPlan(
            title: "Active Recovery",
            estimatedCalories: Double(input.availableMinutes) * 2.5,
            durationMinutes: input.availableMinutes,
            intensity: .light,
            exercises: blocks,
            sourceProvider: "FitCoach",
            safetyNotes: ["Stop if you feel pain, dizziness, or any discomfort."]
        )
    }
}
