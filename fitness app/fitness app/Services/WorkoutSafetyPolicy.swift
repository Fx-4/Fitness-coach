import Foundation

// MARK: - Safety Policy (HealthyAgent — Lab Part 3)
// Reviews every plan before it reaches the UI.
// No medical claims. Practical guardrails only.

struct WorkoutSafetyPolicy: WorkoutSafetyChecking {

    // MARK: - Limits

    private let maxDurationMinutes = 90
    private let maxCaloriesPerSession: Double = 1200
    private let heavyIntensityConsecutiveLimit = 2   // flag after 2 vigorous sessions in a row

    // MARK: - Protocol

    func validate(_ plan: WorkoutPlan, input: RecommendationInput) -> SafetyResult {
        var warnings: [String] = []

        // 1. Duration cap
        if plan.durationMinutes > maxDurationMinutes {
            return .needsShorterDuration(maxDurationMinutes)
        }

        // 2. Calorie cap (no extreme promises)
        if plan.estimatedCalories > maxCaloriesPerSession {
            warnings.append("Calorie estimates are approximate — listen to your body.")
        }

        // 3. Vigorous after recent vigorous sessions
        let recentVigorousCount = input.recentSessions
            .prefix(3)
            .filter { $0.intensity == .vigorous }
            .count
        if recentVigorousCount >= heavyIntensityConsecutiveLimit && plan.intensity == .vigorous {
            return .needsLowerIntensity
        }

        // 4. Very short sessions — warn about warm-up
        if plan.durationMinutes < 10 {
            warnings.append("Short session — include a brief warm-up before any high-effort work.")
        }

        // 5. Standard stop-if-pain note always appended
        warnings.append("Stop if you feel pain, dizziness, or any discomfort.")

        return warnings.isEmpty ? .approved : .approvedWithWarnings(warnings)
    }

    // MARK: - Apply result to plan

    func apply(_ result: SafetyResult, to plan: inout WorkoutPlan, input: RecommendationInput) {
        switch result {
        case .approved:
            plan.safetyNotes = ["Stop if you feel pain, dizziness, or any discomfort."]

        case .approvedWithWarnings(let notes):
            plan.safetyNotes = notes

        case .needsLowerIntensity:
            plan.intensity = .moderate
            plan.safetyNotes = [
                "You've had several intense sessions recently. A moderate session today supports recovery.",
                "Stop if you feel pain, dizziness, or any discomfort."
            ]
            // Reduce calorie estimate proportionally
            plan.estimatedCalories *= 0.7

        case .needsShorterDuration(let maxMin):
            plan.durationMinutes = maxMin
            plan.estimatedCalories = Double(maxMin) * plan.intensity.caloriesPerMinute
            plan.safetyNotes = [
                "Session capped at \(maxMin) minutes.",
                "Stop if you feel pain, dizziness, or any discomfort."
            ]
        }
    }
}
