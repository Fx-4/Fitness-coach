import SwiftUI

struct WorkoutDetailView: View {
    let recommendation: WorkoutRecommendation
    @EnvironmentObject private var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var workoutVM: WorkoutViewModel
    @State private var showingSessionSheet = false
    @State private var burnedCalories: Double = 0
    @State private var sessionNotes = ""
    @State private var isImprovingNotes = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                headerCard
                exerciseList

                if workoutVM.isSessionActive {
                    activeSessionBanner
                } else {
                    startButton
                }
            }
            .padding(DesignTokens.Spacing.md)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(recommendation.title)
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSessionSheet) {
            finishSessionSheet
        }
    }

    // MARK: - Subviews

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: recommendation.type.systemImage)
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading) {
                    Text(recommendation.type.rawValue)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text("\(recommendation.durationMinutes) min · \(recommendation.difficulty.rawValue)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(recommendation.description)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    private var exerciseList: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Exercises")
                .font(.headline)
                .foregroundStyle(.primary)
            ForEach(recommendation.exercises) { ExerciseBlueprintRow(exercise: $0) }
        }
    }

    private var startButton: some View {
        Button {
            workoutVM.startSession(
                type: recommendation.type,
                difficulty: recommendation.difficulty
            )
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        }
        .accessibilityLabel("Start \(recommendation.title) workout")
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
            }
            .padding(DesignTokens.Spacing.md)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

            Button {
                showingSessionSheet = true
            } label: {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
            .accessibilityLabel("Finish workout session")
        }
    }

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
                        showingSessionSheet = false
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
                    Button("Cancel") { showingSessionSheet = false }
                }
            }
        }
        .presentationDetents([.large])
    }
}
