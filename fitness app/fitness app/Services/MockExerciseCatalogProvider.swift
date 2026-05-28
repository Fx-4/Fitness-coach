import Foundation

// MARK: - Mock Exercise Catalog
// Provides candidate exercises for the recommendation engine.
// Architecture: protocol-based so a real API Ninjas / ExerciseDB client
// can be swapped in by conforming to ExerciseCatalogProviding.

struct MockExerciseCatalogProvider: ExerciseCatalogProviding {

    // MARK: - Protocol

    func fetchCandidates(query: ExerciseSearchQuery) async throws -> [ExerciseTemplate] {
        // Filter the catalog by query fields; simulate a lightweight "API response"
        var results = Self.catalog

        if let type = query.type {
            results = results.filter { $0.type == type }
        }
        if let difficulty = query.difficulty {
            // Include same difficulty and one adjacent level for variety
            results = results.filter { ex in
                ex.difficulty == difficulty
                || (difficulty == .moderate && ex.difficulty == .light)
                || (difficulty == .vigorous && ex.difficulty == .moderate)
            }
        }
        if let muscle = query.muscle {
            results = results.filter {
                $0.primaryMuscle?.lowercased().contains(muscle.lowercased()) == true
            }
        }

        return Array(results.prefix(query.limit))
    }

    // MARK: - Fallback (used when provider throws)

    static let fallbackExercises: [ExerciseTemplate] = [
        catalog.first { $0.type == .stretching }!,
        catalog.first { $0.type == .cardio }!,
        catalog.first { $0.type == .strength }!,
    ]

    // MARK: - Internal Catalog

    static let catalog: [ExerciseTemplate] = [

        // ── Warm-up / Stretching ────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_warmup_march",
            name: "High Knee March",
            type: .stretching, difficulty: .light,
            primaryMuscle: "hip flexors", equipment: [],
            instructions: "March in place, drive knees to hip height. Keep core engaged.",
            safetyInfo: "Stop if you feel knee pain.",
            sourceProvider: "FitCoach", caloriesPerMinute: 3.0
        ),
        ExerciseTemplate(
            id: "ex_warmup_armcircle",
            name: "Arm Circles & Shoulder Rolls",
            type: .stretching, difficulty: .light,
            primaryMuscle: "shoulders", equipment: [],
            instructions: "10 forward, 10 backward. Keep breathing.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 2.0
        ),
        ExerciseTemplate(
            id: "ex_cooldown_child",
            name: "Child's Pose",
            type: .stretching, difficulty: .light,
            primaryMuscle: "back", equipment: [],
            instructions: "Sink hips to heels, arms extended. Hold 30–60 s.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 1.5
        ),
        ExerciseTemplate(
            id: "ex_cooldown_foam",
            name: "Foam Roll — Quads & IT Band",
            type: .stretching, difficulty: .light,
            primaryMuscle: "quads", equipment: ["foam roller"],
            instructions: "Slow rolls, pause on tight spots. 45 s per leg.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 2.0
        ),
        ExerciseTemplate(
            id: "ex_stretch_hip",
            name: "Hip Flexor Stretch",
            type: .stretching, difficulty: .light,
            primaryMuscle: "hip flexors", equipment: [],
            instructions: "Low lunge, press hips forward. 30 s each side.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 1.8
        ),

        // ── Light Cardio ────────────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_walk_brisk",
            name: "Brisk Walk",
            type: .cardio, difficulty: .light,
            primaryMuscle: "legs", equipment: [],
            instructions: "Maintain a pace where you can hold a conversation.",
            safetyInfo: "Stay hydrated. Stop if dizzy or short of breath.",
            sourceProvider: "FitCoach", caloriesPerMinute: 4.5
        ),
        ExerciseTemplate(
            id: "ex_cycle_easy",
            name: "Easy Cycling",
            type: .cardio, difficulty: .light,
            primaryMuscle: "quads", equipment: ["bicycle"],
            instructions: "Flat road or low resistance. Comfortable cadence.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 5.0
        ),

        // ── Moderate Cardio ─────────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_jog",
            name: "Steady Jog",
            type: .cardio, difficulty: .moderate,
            primaryMuscle: "legs", equipment: [],
            instructions: "Comfortable pace, land midfoot. Breathe rhythmically.",
            safetyInfo: "Stop if you feel chest tightness, dizziness, or discomfort.",
            sourceProvider: "FitCoach", caloriesPerMinute: 9.0
        ),
        ExerciseTemplate(
            id: "ex_jump_rope",
            name: "Jump Rope",
            type: .cardio, difficulty: .moderate,
            primaryMuscle: "calves", equipment: ["jump rope"],
            instructions: "Land softly on balls of feet. Keep wrists relaxed.",
            safetyInfo: "Land gently to protect joints.",
            sourceProvider: "FitCoach", caloriesPerMinute: 10.0
        ),

        // ── Moderate Strength ───────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_squat_goblet",
            name: "Goblet Squat",
            type: .strength, difficulty: .moderate,
            primaryMuscle: "quads", equipment: ["dumbbell"],
            instructions: "Hold weight at chest, sit back and down. Chest stays tall.",
            safetyInfo: "Keep knees tracking over toes.",
            sourceProvider: "FitCoach", caloriesPerMinute: 6.0
        ),
        ExerciseTemplate(
            id: "ex_pushup",
            name: "Push-Up",
            type: .strength, difficulty: .moderate,
            primaryMuscle: "chest", equipment: [],
            instructions: "Maintain a straight line from heels to head. Lower with control.",
            safetyInfo: "Drop to knees to reduce load.",
            sourceProvider: "FitCoach", caloriesPerMinute: 5.5
        ),
        ExerciseTemplate(
            id: "ex_row_db",
            name: "Dumbbell Row",
            type: .strength, difficulty: .moderate,
            primaryMuscle: "back", equipment: ["dumbbell"],
            instructions: "Brace core, drive elbow toward ceiling. No twisting.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 5.0
        ),
        ExerciseTemplate(
            id: "ex_glute_bridge",
            name: "Glute Bridge",
            type: .strength, difficulty: .light,
            primaryMuscle: "glutes", equipment: [],
            instructions: "Drive hips up, squeeze glutes at top. Keep ribs down.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 4.0
        ),

        // ── Core ────────────────────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_plank",
            name: "Plank Hold",
            type: .core, difficulty: .moderate,
            primaryMuscle: "core", equipment: [],
            instructions: "Neutral spine, brace as if expecting a punch. Breathe.",
            safetyInfo: "Stop if lower back dips or pain occurs.",
            sourceProvider: "FitCoach", caloriesPerMinute: 3.5
        ),
        ExerciseTemplate(
            id: "ex_deadbug",
            name: "Dead Bug",
            type: .core, difficulty: .light,
            primaryMuscle: "core", equipment: [],
            instructions: "Extend opposite arm/leg. Press lower back into floor.",
            safetyInfo: nil,
            sourceProvider: "FitCoach", caloriesPerMinute: 3.0
        ),

        // ── Vigorous / Plyometrics ──────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_burpee",
            name: "Burpee",
            type: .plyometrics, difficulty: .vigorous,
            primaryMuscle: "full body", equipment: [],
            instructions: "Chest to floor, explosive jump at top. Full extension.",
            safetyInfo: "Reduce pace or step instead of jumping if needed.",
            sourceProvider: "FitCoach", caloriesPerMinute: 11.0
        ),
        ExerciseTemplate(
            id: "ex_mountain_climber",
            name: "Mountain Climbers",
            type: .plyometrics, difficulty: .vigorous,
            primaryMuscle: "core", equipment: [],
            instructions: "Hips level, drive knees to chest alternately. Fast pace.",
            safetyInfo: "Slow down if form breaks.",
            sourceProvider: "FitCoach", caloriesPerMinute: 10.0
        ),
        ExerciseTemplate(
            id: "ex_jump_squat",
            name: "Jump Squat",
            type: .plyometrics, difficulty: .vigorous,
            primaryMuscle: "quads", equipment: [],
            instructions: "Squat to parallel, explode up. Land softly with bent knees.",
            safetyInfo: "Step if joint pain present.",
            sourceProvider: "FitCoach", caloriesPerMinute: 9.5
        ),
        ExerciseTemplate(
            id: "ex_hiit_circuit",
            name: "HIIT Circuit (20/10)",
            type: .cardio, difficulty: .vigorous,
            primaryMuscle: "full body", equipment: [],
            instructions: "20 s max effort, 10 s rest. Repeat 8 rounds. Choose any 2 moves.",
            safetyInfo: "Stop if chest pain or dizziness occurs.",
            sourceProvider: "FitCoach", caloriesPerMinute: 13.0
        ),

        // ── Heavy Strength ──────────────────────────────────────────────────
        ExerciseTemplate(
            id: "ex_deadlift",
            name: "Deadlift",
            type: .strength, difficulty: .vigorous,
            primaryMuscle: "hamstrings", equipment: ["barbell"],
            instructions: "Bar over mid-foot, neutral spine, hinge then push. Brace core.",
            safetyInfo: "Do not round lower back. Use lighter weight to learn form first.",
            sourceProvider: "FitCoach", caloriesPerMinute: 6.5
        ),
        ExerciseTemplate(
            id: "ex_bench_press",
            name: "Bench Press",
            type: .strength, difficulty: .vigorous,
            primaryMuscle: "chest", equipment: ["barbell", "bench"],
            instructions: "Control the descent 2 s. Drive feet into floor, arch naturally.",
            safetyInfo: "Use a spotter for heavy sets.",
            sourceProvider: "FitCoach", caloriesPerMinute: 6.0
        ),
    ]
}

// MARK: - Mock Calorie Estimator

struct MockCalorieEstimator: CalorieEstimating {
    func estimateCalories(
        activityName: String,
        weightPounds: Double?,
        durationMinutes: Int
    ) async throws -> CalorieEstimate {
        // Simple rule: look up in catalog by name, else default 6 kcal/min
        let rate = MockExerciseCatalogProvider.catalog
            .first { $0.name.lowercased() == activityName.lowercased() }?
            .caloriesPerMinute ?? 6.0

        // Weight adjustment: +/- 5% per 10 lbs from 154 lb baseline
        let weightFactor: Double
        if let lbs = weightPounds {
            weightFactor = 1.0 + (lbs - 154.0) / 154.0 * 0.3
        } else {
            weightFactor = 1.0
        }

        let total = rate * Double(durationMinutes) * max(0.7, min(1.5, weightFactor))
        return CalorieEstimate(
            activityName: activityName,
            durationMinutes: durationMinutes,
            totalCalories: total,
            caloriesPerMinute: total / max(1, Double(durationMinutes))
        )
    }
}
