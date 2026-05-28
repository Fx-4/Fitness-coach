import SwiftUI

@MainActor
final class WorkoutViewModel: ObservableObject {
    @Published var recommendations: [WorkoutRecommendation] = []
    @Published var activeSession: WorkoutSession? = nil
    @Published var elapsedSeconds: Int = 0
    @Published var isSessionActive = false

    // Lesson 9: AI plan generation
    @Published var currentPlan: WorkoutPlan? = nil
    @Published var isGeneratingPlan = false
    @Published var planError: String? = nil
    @Published var preferredIntensity: WorkoutIntensity = .moderate
    @Published var availableMinutes: Int = 30

    private let recommender: WorkoutRecommenderProtocol
    private let engine = WorkoutRecommendationEngine.shared
    private var timerTask: Task<Void, Never>? = nil

    init(recommender: WorkoutRecommenderProtocol = WorkoutRecommender.shared) {
        self.recommender = recommender
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Classic recommendations (fitness-level based)

    func loadRecommendations(store: AppDataStore) {
        let recent = store.recentSessions
        let last   = recent.first
        let input  = WorkoutProfileInput(
            fitnessLevel: store.profile.fitnessLevel,
            recentSessionCount: recent.count,
            lastSessionCalories: last?.activeCaloriesBurned,
            lastSessionType: last?.workoutType,
            todayCaloriesBurned: store.todaySessionCalories
        )
        recommendations = recommender.recommendations(for: input)
    }

    // MARK: - AI plan generation (Lesson 9 engine)

    func generatePlan(store: AppDataStore) {
        isGeneratingPlan = true
        planError = nil
        let weightPounds = store.profile.weightKg * 2.20462
        let recentSummaries: [WorkoutSessionSummary] = store.recentSessions.map { s in
            WorkoutSessionSummary(
                date: s.startedAt,
                exerciseType: s.workoutType.asExerciseType,
                durationMinutes: s.durationSeconds / 60,
                estimatedCalories: s.activeCaloriesBurned,
                intensity: s.difficulty.asWorkoutIntensity
            )
        }
        let input = RecommendationInput(
            targetCalories: Double(store.profile.dailyCalorieGoal),
            activeEnergyBurned: store.todaySessionCalories,
            availableMinutes: availableMinutes,
            preferredIntensity: preferredIntensity,
            bodyWeightPounds: weightPounds,
            recentSessions: recentSummaries
        )
        Task {
            do {
                let plan = try await engine.recommendPlan(input: input)
                currentPlan = plan
                isGeneratingPlan = false
            } catch {
                planError = "Could not generate plan. Try again."
                isGeneratingPlan = false
            }
        }
    }

    // MARK: - Session management

    func startSession(type: WorkoutType, difficulty: WorkoutDifficulty) {
        var session = WorkoutSession()
        session.workoutType = type
        session.difficulty  = difficulty
        session.startedAt   = Date()
        activeSession  = session
        isSessionActive = true
        elapsedSeconds  = 0
        startTimer()
    }

    func startSessionFromPlan(_ plan: WorkoutPlan) {
        let type: WorkoutType
        switch plan.intensity {
        case .light:    type = .cardio
        case .moderate: type = .strength
        case .vigorous: type = .hiit
        }
        startSession(type: type, difficulty: plan.intensity.difficulty)
    }

    func finishSession(calories: Double, notes: String = "", store: AppDataStore) {
        timerTask?.cancel()
        timerTask = nil
        guard var session = activeSession else { return }
        session.completedAt          = Date()
        session.isCompleted          = true
        session.durationSeconds      = elapsedSeconds
        session.activeCaloriesBurned = calories
        session.notes                = notes
        store.addSession(session)
        isSessionActive = false
        activeSession   = nil
    }

    func cancelSession() {
        timerTask?.cancel()
        timerTask    = nil
        isSessionActive = false
        activeSession   = nil
    }

    // MARK: - Private

    private func startTimer() {
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                self?.elapsedSeconds += 1
            }
        }
    }
}

// MARK: - Type mapping helpers

private extension WorkoutType {
    var asExerciseType: ExerciseType {
        switch self {
        case .strength:                    return .strength
        case .cardio:                      return .cardio
        case .hiit:                        return .cardio
        case .yoga, .mobility, .recovery:  return .stretching
        }
    }
}

private extension WorkoutDifficulty {
    var asWorkoutIntensity: WorkoutIntensity {
        switch self {
        case .easy:     return .light
        case .moderate: return .moderate
        case .hard:     return .vigorous
        }
    }
}
