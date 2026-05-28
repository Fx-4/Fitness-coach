import SwiftUI

struct ExerciseBlueprintRow: View {
    let exercise: ExerciseBlueprint

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text(exercise.muscleGroup.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(.tint.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
            }

            Text(volumeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !exercise.instructions.isEmpty {
                Text(exercise.instructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }

    private var volumeLabel: String {
        if exercise.durationSeconds > 0 {
            let minutes = exercise.durationSeconds / 60
            let seconds = exercise.durationSeconds % 60
            return minutes > 0 ? "\(exercise.sets)×  \(minutes)m \(seconds)s" : "\(exercise.sets)×  \(seconds)s"
        } else {
            return "\(exercise.sets) sets × \(exercise.reps) reps"
        }
    }
}
