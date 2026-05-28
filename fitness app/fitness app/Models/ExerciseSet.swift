import Foundation

struct ExerciseSet: Codable, Identifiable {
    var id: UUID = UUID()
    var exerciseName: String = ""
    var muscleGroup: MuscleGroup = .chest
    var reps: Int = 0
    var sets: Int = 1
    var weightKg: Double = 0.0
    var durationSeconds: Int = 0
    var completedAt: Date = Date()
    var formScore: Double? = nil
}

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest     = "Chest"
    case back      = "Back"
    case shoulders = "Shoulders"
    case biceps    = "Biceps"
    case triceps   = "Triceps"
    case core      = "Core"
    case quads     = "Quads"
    case hamstrings = "Hamstrings"
    case glutes    = "Glutes"
    case calves    = "Calves"
    case fullBody  = "Full Body"
    case cardio    = "Cardio"

    var id: String { rawValue }
}
