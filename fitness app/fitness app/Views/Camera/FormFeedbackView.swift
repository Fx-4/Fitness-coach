import SwiftUI

struct FormFeedbackView: View {
    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var store: AppDataStore

    @State private var isPanelExpanded = true
    @State private var burnedCalories: Double = 0
    @State private var sessionNotes: String = ""
    @State private var isImprovingNotes = false

    private let exercises = [
        "Squat", "Push-Up", "Plank", "Deadlift", "Lunge", "Burpee"
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                cameraLayer

                // Floating session HUD — top-left, always visible
                if viewModel.isSessionActive {
                    VStack {
                        sessionHUD
                            .padding(.top, 60)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                        Spacer()
                    }
                }

                // Collapsible bottom panel
                bottomPanel
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle("Form Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { cameraToolbar }
            .task { await viewModel.startCamera() }
            .onDisappear { viewModel.stopCamera() }
            .alert("Camera Error",
                   isPresented: .constant(viewModel.cameraError != nil)) {
                Button("OK") { }
            } message: {
                Text(viewModel.cameraError ?? "")
            }
            .sheet(isPresented: $viewModel.showFinishSheet) {
                finishSheet
            }
        }
    }

    // MARK: - Camera background

    private var cameraLayer: some View {
        Group {
            if viewModel.isCameraRunning {
                CameraPreviewView(session: viewModel.session)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Rectangle()
                    .fill(.black)
                    .overlay {
                        VStack(spacing: DesignTokens.Spacing.md) {
                            ProgressView().tint(.white)
                            Text("Starting camera…")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                        }
                    }
            }
        }
    }

    // MARK: - Session HUD (floating over camera, top-left)

    private var sessionHUD: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Timer chip
            HStack(spacing: 4) {
                Image(systemName: "timer").font(.caption.bold())
                Text(viewModel.elapsedFormatted)
                    .font(.caption.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 6)
            .background(.orange)
            .foregroundStyle(.white)
            .clipShape(Capsule())

            // Rep chip
            HStack(spacing: 4) {
                Image(systemName: "arrow.trianglehead.counterclockwise").font(.caption.bold())
                Text("\(viewModel.repCount) reps")
                    .font(.caption.bold())
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 6)
            .background(.black.opacity(0.55))
            .foregroundStyle(.white)
            .clipShape(Capsule())

            // Form score chip
            if viewModel.avgFormScore > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").font(.caption2.bold())
                    Text("\((viewModel.avgFormScore * 100).formatted(.number.precision(.fractionLength(0))))%")
                        .font(.caption.bold())
                }
                .padding(.horizontal, DesignTokens.Spacing.sm)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55))
                .foregroundStyle(hudScoreColor)
                .clipShape(Capsule())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var hudScoreColor: Color {
        switch viewModel.avgFormScore {
        case 0.85...: return .green
        case 0.65...: return .yellow
        default:      return .red
        }
    }

    // MARK: - Collapsible bottom panel

    private var bottomPanel: some View {
        VStack(spacing: 0) {
            // ── drag handle / collapse toggle ──
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isPanelExpanded.toggle()
                }
            } label: {
                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 36, height: 4)
                    Image(systemName: isPanelExpanded ? "chevron.down" : "chevron.up")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }

            // ── expandable content ──
            if isPanelExpanded {
                if let feedback = viewModel.poseFeedback {
                    feedbackBanner(feedback: feedback)
                }
                if viewModel.isSessionActive && !viewModel.repsByExercise.isEmpty {
                    repBreakdownRow
                }
            }

            // ── always visible: exercise picker + session button ──
            exercisePicker
            sessionControls
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Feedback banner

    private func feedbackBanner(feedback: PoseFeedback) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                scoreGauge(score: feedback.score)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(feedback.grade)
                        .font(.title3.bold())
                        .foregroundStyle(gradeColor(feedback.gradeColor))
                    Text("Form: \((feedback.score * 100).formatted(.number.precision(.fractionLength(0))))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !feedback.issues.isEmpty {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    ForEach(feedback.issues, id: \.self) { issue in
                        Label(issue, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                    }
                }
            }
        }
        .padding(DesignTokens.Spacing.md)
        .animation(.easeInOut(duration: 0.3), value: feedback.score)
    }

    // MARK: - Rep breakdown

    private var repBreakdownRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(viewModel.repsByExercise.sorted(by: { $0.key < $1.key }), id: \.key) { name, reps in
                    VStack(spacing: 2) {
                        Text("\(reps)")
                            .font(.caption.bold())
                        Text(name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Exercise picker

    private var exercisePicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(exercises, id: \.self) { exercise in
                    Button {
                        viewModel.updateExercise(exercise)
                    } label: {
                        Text(exercise)
                            .font(.subheadline.bold())
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .background(viewModel.selectedExercise == exercise
                                        ? Color.orange : Color.secondary.opacity(0.2))
                            .foregroundStyle(viewModel.selectedExercise == exercise
                                             ? .white : .primary)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill,
                                                        style: .continuous))
                    }
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Session controls

    private var sessionControls: some View {
        Group {
            if viewModel.isSessionActive {
                Button {
                    burnedCalories = viewModel.estimatedCalories
                    sessionNotes = ""
                    viewModel.stopForFinish()
                } label: {
                    Label("Stop & Save Session", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(.green)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                }
                .padding([.horizontal, .bottom], DesignTokens.Spacing.md)
            } else {
                Button {
                    viewModel.startSession()
                    withAnimation(.easeInOut(duration: 0.25)) { isPanelExpanded = false }
                } label: {
                    Label("Start Session", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                }
                .padding([.horizontal, .bottom], DesignTokens.Spacing.md)
            }
        }
    }

    // MARK: - Finish sheet

    private var finishSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    // Summary chips
                    HStack(spacing: DesignTokens.Spacing.md) {
                        summaryChip(value: viewModel.elapsedFormatted, label: "Duration",
                                    icon: "clock", color: .blue)
                        summaryChip(value: "\(viewModel.repCount)", label: "Total reps",
                                    icon: "arrow.trianglehead.counterclockwise", color: .orange)
                        summaryChip(
                            value: viewModel.avgFormScore > 0
                                ? "\((viewModel.avgFormScore * 100).formatted(.number.precision(.fractionLength(0))))%"
                                : "–",
                            label: "Avg form", icon: "star.fill", color: .yellow)
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

                    // Per-exercise breakdown
                    if !viewModel.repsByExercise.isEmpty {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                            Text("Exercise breakdown")
                                .font(.subheadline.bold())
                            ForEach(viewModel.repsByExercise.sorted(by: { $0.key < $1.key }), id: \.key) { name, reps in
                                HStack {
                                    Text(name).font(.subheadline)
                                    Spacer()
                                    Text("\(reps) reps")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(.orange)
                                }
                                .padding(.vertical, 4)
                                Divider()
                            }
                        }
                        .padding(DesignTokens.Spacing.md)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }

                    // Calories stepper
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        Text("Calories burned")
                            .font(.subheadline.bold())
                        Stepper(value: $burnedCalories, in: 0...2000, step: 5) {
                            Text(burnedCalories.formatted(.number.precision(.fractionLength(0))) + " kcal")
                                .font(.title2.bold())
                        }
                    }
                    .padding(DesignTokens.Spacing.md)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

                    // Notes + AI Improve
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        HStack {
                            Text("Session Notes").font(.subheadline.bold())
                            Spacer()
                            Button {
                                Task {
                                    isImprovingNotes = true
                                    if let improved = try? await AIService.shared.improveText(
                                        sessionNotes, hint: "form coach session note") {
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
                            .disabled(sessionNotes.trimmingCharacters(in: .whitespaces).isEmpty
                                      || isImprovingNotes)
                        }
                        TextEditor(text: $sessionNotes)
                            .frame(minHeight: 80)
                            .padding(DesignTokens.Spacing.xs)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                            .overlay(
                                Group {
                                    if sessionNotes.isEmpty {
                                        Text("How did the session feel?")
                                            .foregroundStyle(.tertiary)
                                            .padding(.leading, 8).padding(.top, 12)
                                            .allowsHitTesting(false)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity,
                                                   alignment: .topLeading)
                                    }
                                }
                            )
                    }

                    Button("Save & Finish") {
                        viewModel.saveSession(calories: burnedCalories, notes: sessionNotes, store: store)
                        withAnimation(.easeInOut(duration: 0.25)) { isPanelExpanded = true }
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
            .navigationTitle("Session Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showFinishSheet = false
                        viewModel.startSession()    // resume
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var cameraToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Label("Camera", systemImage: "circle.fill")
                .foregroundStyle(viewModel.isCameraRunning ? .green : .red)
                .font(.caption)
                .labelStyle(.iconOnly)
        }
    }

    // MARK: - Helpers

    private func summaryChip(value: String, label: String,
                              icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.headline).foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func scoreGauge(score: Double) -> some View {
        ZStack {
            Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 4)
            Circle()
                .trim(from: 0, to: score)
                .stroke(gradeColor(gradeColorString(score)),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: score)
        }
        .frame(width: 44, height: 44)
    }

    private func gradeColorString(_ score: Double) -> String {
        switch score {
        case 0.85...: return "green"
        case 0.65...: return "yellow"
        default: return "red"
        }
    }

    private func gradeColor(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "yellow": return .yellow
        default: return .red
        }
    }
}
