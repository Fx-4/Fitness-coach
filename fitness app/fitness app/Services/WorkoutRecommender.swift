import Foundation

final class WorkoutRecommender: WorkoutRecommenderProtocol {
    static let shared = WorkoutRecommender()
    private init() {}

    // Recovery is recommended if the last session burned >= 600 kcal
    private let recoveryThreshold: Double = 600

    func recommendations(for input: WorkoutProfileInput) -> [WorkoutRecommendation] {
        if shouldRecommendRecovery(input) {
            return [recoveryDay()]
        }

        var recs: [WorkoutRecommendation] = []

        switch input.fitnessLevel {
        case .beginner:
            recs = beginnerRecommendations(input)
        case .intermediate:
            recs = intermediateRecommendations(input)
        case .advanced:
            recs = advancedRecommendations(input)
        }

        return Array(recs.prefix(3))
    }

    // MARK: - Recovery

    private func shouldRecommendRecovery(_ input: WorkoutProfileInput) -> Bool {
        guard let lastCal = input.lastSessionCalories else { return false }
        return lastCal >= recoveryThreshold
    }

    private func recoveryDay() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .recovery,
            title: "Recovery Day",
            description: "Your body needs rest after that intense session. Light mobility work today.",
            durationMinutes: 20,
            difficulty: .easy,
            exercises: [
                ExerciseBlueprint(name: "Foam Rolling", muscleGroup: .fullBody, sets: 1, reps: 0, durationSeconds: 300, instructions: "Roll each major muscle group for 30 seconds."),
                ExerciseBlueprint(name: "Child's Pose", muscleGroup: .back, sets: 3, reps: 0, durationSeconds: 30, instructions: "Hold gently, breathe deeply."),
                ExerciseBlueprint(name: "Hip Flexor Stretch", muscleGroup: .glutes, sets: 2, reps: 0, durationSeconds: 30, instructions: "Lunge forward, press hips down.")
            ]
        )
    }

    // MARK: - Beginner

    private func beginnerRecommendations(_ input: WorkoutProfileInput) -> [WorkoutRecommendation] {
        let avoidType = input.lastSessionType
        return [
            fullBodyStrength(difficulty: .easy, avoidSameAs: avoidType),
            beginnerCardio(),
            mobilitySession()
        ].compactMap { $0 }
    }

    private func fullBodyStrength(difficulty: WorkoutDifficulty, avoidSameAs: WorkoutType?) -> WorkoutRecommendation? {
        WorkoutRecommendation(
            type: .strength,
            title: "Full Body Strength",
            description: "Build a solid foundation with compound movements.",
            durationMinutes: difficulty == .easy ? 30 : 45,
            difficulty: difficulty,
            exercises: [
                ExerciseBlueprint(name: "Goblet Squat", muscleGroup: .quads, sets: 3, reps: 12, instructions: "Keep chest tall, drive knees out."),
                ExerciseBlueprint(name: "Push-Up", muscleGroup: .chest, sets: 3, reps: 10, instructions: "Maintain plank position throughout."),
                ExerciseBlueprint(name: "Dumbbell Row", muscleGroup: .back, sets: 3, reps: 10, instructions: "Drive elbow to ceiling, not behind."),
                ExerciseBlueprint(name: "Plank", muscleGroup: .core, sets: 3, reps: 0, durationSeconds: 30, instructions: "Neutral spine, brace your core.")
            ]
        )
    }

    private func beginnerCardio() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .cardio,
            title: "Steady-State Walk/Jog",
            description: "Low-impact cardio to build aerobic base.",
            durationMinutes: 25,
            difficulty: .easy,
            exercises: [
                ExerciseBlueprint(name: "Brisk Walk", muscleGroup: .cardio, sets: 1, reps: 0, durationSeconds: 1500, instructions: "Maintain a pace where you can hold a conversation.")
            ]
        )
    }

    // MARK: - Intermediate

    private func intermediateRecommendations(_ input: WorkoutProfileInput) -> [WorkoutRecommendation] {
        [
            pushPullLegs(difficulty: .moderate),
            hiitSession(difficulty: .moderate),
            mobilitySession()
        ].compactMap { $0 }
    }

    private func pushPullLegs(difficulty: WorkoutDifficulty) -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .strength,
            title: "Push Day",
            description: "Chest, shoulders, and triceps hypertrophy focus.",
            durationMinutes: 50,
            difficulty: difficulty,
            exercises: [
                ExerciseBlueprint(name: "Bench Press", muscleGroup: .chest, sets: 4, reps: 8, instructions: "Control the descent for 2 seconds."),
                ExerciseBlueprint(name: "Overhead Press", muscleGroup: .shoulders, sets: 3, reps: 10, instructions: "Keep core braced, no lower back arch."),
                ExerciseBlueprint(name: "Lateral Raise", muscleGroup: .shoulders, sets: 3, reps: 15, instructions: "Slight forward lean, pinky leads."),
                ExerciseBlueprint(name: "Tricep Dip", muscleGroup: .triceps, sets: 3, reps: 12, instructions: "Elbows track back, not flared.")
            ]
        )
    }

    private func hiitSession(difficulty: WorkoutDifficulty) -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .hiit,
            title: "HIIT Circuit",
            description: "20s work / 10s rest × 8 rounds. Max effort each interval.",
            durationMinutes: 25,
            difficulty: difficulty,
            exercises: [
                ExerciseBlueprint(name: "Burpee", muscleGroup: .fullBody, sets: 8, reps: 0, durationSeconds: 20, instructions: "Jump at the top, chest to floor at the bottom."),
                ExerciseBlueprint(name: "Mountain Climber", muscleGroup: .core, sets: 8, reps: 0, durationSeconds: 20, instructions: "Keep hips level, drive knees to chest fast."),
                ExerciseBlueprint(name: "Jump Squat", muscleGroup: .quads, sets: 8, reps: 0, durationSeconds: 20, instructions: "Soft landing, full depth squat.")
            ]
        )
    }

    // MARK: - Advanced

    private func advancedRecommendations(_ input: WorkoutProfileInput) -> [WorkoutRecommendation] {
        [
            olympicStrength(),
            advancedHIIT(),
            yogaSession()
        ].compactMap { $0 }
    }

    private func olympicStrength() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .strength,
            title: "Olympic Strength",
            description: "Heavy compound lifts with progressive overload.",
            durationMinutes: 70,
            difficulty: .hard,
            exercises: [
                ExerciseBlueprint(name: "Back Squat", muscleGroup: .quads, sets: 5, reps: 5, instructions: "Below parallel, brace before unracking."),
                ExerciseBlueprint(name: "Deadlift", muscleGroup: .hamstrings, sets: 4, reps: 4, instructions: "Bar over mid-foot, neutral spine, hinge then push."),
                ExerciseBlueprint(name: "Weighted Pull-Up", muscleGroup: .back, sets: 4, reps: 6, instructions: "Full hang, chin above bar, controlled descent.")
            ]
        )
    }

    private func advancedHIIT() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .hiit,
            title: "Tabata Complex",
            description: "4-exercise Tabata complex, 4 rounds. No rest between exercises.",
            durationMinutes: 30,
            difficulty: .hard,
            exercises: [
                ExerciseBlueprint(name: "Clean & Press", muscleGroup: .fullBody, sets: 4, reps: 0, durationSeconds: 20, instructions: "Explosive pull from floor, press overhead."),
                ExerciseBlueprint(name: "Box Jump", muscleGroup: .quads, sets: 4, reps: 0, durationSeconds: 20, instructions: "Full hip extension at top, step down carefully.")
            ]
        )
    }

    // MARK: - Shared

    private func mobilitySession() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .mobility,
            title: "Mobility Flow",
            description: "Improve range of motion and reduce injury risk.",
            durationMinutes: 20,
            difficulty: .easy,
            exercises: [
                ExerciseBlueprint(name: "World's Greatest Stretch", muscleGroup: .fullBody, sets: 3, reps: 5, instructions: "Lunge, rotate, reach — one fluid movement."),
                ExerciseBlueprint(name: "90/90 Hip Switch", muscleGroup: .glutes, sets: 2, reps: 10, instructions: "Keep spine tall, rotate hips actively."),
                ExerciseBlueprint(name: "Thoracic Rotation", muscleGroup: .back, sets: 2, reps: 10, instructions: "Fix hips, rotate chest toward ceiling.")
            ]
        )
    }

    private func yogaSession() -> WorkoutRecommendation {
        WorkoutRecommendation(
            type: .yoga,
            title: "Strength Yoga",
            description: "Balance, flexibility, and body-weight strength.",
            durationMinutes: 40,
            difficulty: .moderate,
            exercises: [
                ExerciseBlueprint(name: "Warrior III", muscleGroup: .glutes, sets: 2, reps: 0, durationSeconds: 30, instructions: "Engage core, level hips, flex standing foot."),
                ExerciseBlueprint(name: "Chair Pose", muscleGroup: .quads, sets: 3, reps: 0, durationSeconds: 45, instructions: "Sit back as if into a chair, arms overhead."),
                ExerciseBlueprint(name: "Crow Pose", muscleGroup: .core, sets: 3, reps: 0, durationSeconds: 20, instructions: "Lean forward, knees on triceps, engage core.")
            ]
        )
    }
}
