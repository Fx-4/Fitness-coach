import SwiftUI

struct WorkoutPlanDetailView: View {
    let plan: WorkoutPlan
    @ObservedObject var workoutVM: WorkoutViewModel
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var showFinishSheet = false
    @State private var burnedCalories: Double = 0
    @State private var sessionNotes = ""
    @State private var isImprovingNotes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    headerStatsRow
                    exercisesSection
                    if !plan.safetyNotes.isEmpty { safetySection }
                    if workoutVM.isSessionActive {
                        activeSessionBanner
                    } else {
                        startButton
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle(plan.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showFinishSheet) {
                finishSessionSheet
            }
        }
    }

    // MARK: - Header Stats

    private var headerStatsRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            PlanStatCell(value: "\(plan.durationMinutes)", unit: "min",
                         icon: "clock", color: .blue)
            PlanStatCell(value: plan.estimatedCaloriesFormatted, unit: "kcal est.",
                         icon: "flame.fill", color: .orange)
            PlanStatCell(value: plan.intensity.rawValue, unit: "intensity",
                         icon: plan.intensity.systemImage, color: .purple)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    // MARK: - Exercises

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(.primary)
            ForEach(plan.exercises) { block in
                ExerciseBlockRow(block: block)
            }
        }
    }

    // MARK: - Safety Notes

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("Safety Notes", systemImage: "shield.checkered")
                .font(.subheadline.bold())
                .foregroundStyle(.secondary)
            ForEach(plan.safetyNotes, id: \.self) { note in
                HStack(alignment: .top, spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .padding(.top, 2)
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }

    // MARK: - Start / Active Session

    private var startButton: some View {
        Button {
            workoutVM.startSessionFromPlan(plan)
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        }
    }

    private var activeSessionBanner: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            HStack {
                Image(systemName: "timer").foregroundStyle(.orange)
                Text(workoutVM.elapsedFormatted)
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                Spacer()
                Text("In progress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignTokens.Spacing.md)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

            Button {
                burnedCalories = plan.estimatedCalories
                showFinishSheet = true
            } label: {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
        }
    }

    // MARK: - Finish sheet

    private var finishSessionSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Calories
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Calories burned")
                            .font(.subheadline.bold())
                        Stepper(value: $burnedCalories, in: 0...2000, step: 10) {
                            Text(burnedCalories.formatted(.number.precision(.fractionLength(0))) + " kcal")
                                .font(.title2.bold())
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

                    // Notes + AI improve
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Text("Session Notes")
                                .font(.subheadline.bold())
                            Spacer()
                            Button {
                                Task {
                                    isImprovingNotes = true
                                    if let improved = try? await AIService.shared.improveText(sessionNotes) {
                                        sessionNotes = improved
                                    }
                                    isImprovingNotes = false
                                }
                            } label: {
                                Label(isImprovingNotes ? "Improving…" : "AI Improve",
                                      systemImage: "sparkles")
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.orange.opacity(isImprovingNotes ? 0.4 : 1.0))
                            }
                            .disabled(sessionNotes.trimmingCharacters(in: .whitespaces).isEmpty || isImprovingNotes)
                        }
                        TextEditor(text: $sessionNotes)
                            .frame(minHeight: 90)
                            .padding(DesignTokens.Spacing.xs)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                            .overlay(
                                Group {
                                    if sessionNotes.isEmpty {
                                        Text("How did it go? What felt strong?")
                                            .foregroundStyle(.tertiary)
                                            .padding(.leading, 8)
                                            .padding(.top, 12)
                                            .allowsHitTesting(false)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    }
                                }
                            )
                    }

                    Button("Save & Finish") {
                        workoutVM.finishSession(calories: burnedCalories, notes: sessionNotes, store: store)
                        showFinishSheet = false
                        dismiss()
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                }
                .padding(DesignTokens.Spacing.lg)
            }
            .navigationTitle("Finish Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { showFinishSheet = false }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - PlanStatCell

private struct PlanStatCell: View {
    let value: String
    let unit: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline)
                .foregroundStyle(.primary)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - ExerciseBlockRow

struct ExerciseBlockRow: View {
    let block: ExerciseBlock

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack {
                Text(block.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Spacer()
                Text(block.displayRepsOrDuration)
                    .font(.caption.bold())
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(.tint.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
            }

            if block.sets > 1 {
                Text("\(block.sets) sets")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !block.instructions.isEmpty {
                Text(block.instructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let note = block.safetyNote {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}
