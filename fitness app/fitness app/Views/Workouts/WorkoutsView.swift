import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject private var store: AppDataStore
    @StateObject private var workoutVM = WorkoutViewModel()
    @State private var path = NavigationPath()
    @State private var selectedPlan: WorkoutPlan? = nil
    @State private var activityTab: ActivityTab = .today
    @State private var showScheduleLibrary = false
    @State private var editingSchedule: CoachScheduleDraft? = nil

    private enum ActivityTab: String, CaseIterable {
        case today = "Today"
        case week  = "This Week"
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    activeScheduleSection
                    smartPlanSection
                    recommendationsSection
                    activitySection
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showScheduleLibrary = true
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .accessibilityLabel("Open saved schedules")
                }
            }
            .navigationDestination(for: WorkoutRecommendation.self) { rec in
                WorkoutDetailView(recommendation: rec, workoutVM: workoutVM)
            }
            .sheet(item: $selectedPlan) { plan in
                WorkoutPlanDetailView(plan: plan, workoutVM: workoutVM)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showScheduleLibrary) {
                ScheduleLibraryView(
                    schedules: store.savedCoachSchedules,
                    onAdd: {
                        editingSchedule = .blank()
                    },
                    onEdit: { draft in
                        editingSchedule = draft
                    },
                    onDelete: { draft in
                        store.deleteCoachSchedule(draft)
                    }
                )
                .environmentObject(store)
            }
            .sheet(item: $editingSchedule) { draft in
                CoachScheduleEditorView(initialDraft: draft) { updatedDraft in
                    store.upsertCoachSchedule(updatedDraft)
                    editingSchedule = nil
                }
            }
            .task {
                workoutVM.loadRecommendations(store: store)
            }
        }
    }

    // MARK: - Active Schedule Banner

    @ViewBuilder
    private var activeScheduleSection: some View {
        let schedules = store.savedCoachSchedules
        if !schedules.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    Label("My Schedule", systemImage: "calendar.badge.checkmark")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button("View All") { showScheduleLibrary = true }
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }

                // Show today's workout if matching day exists
                if let todayDay = todayScheduleDay(from: schedules.first) {
                    TodayScheduleDayCard(day: todayDay)
                } else {
                    // Show first schedule summary
                    Button { showScheduleLibrary = true } label: {
                        ScheduleSummaryCard(draft: schedules[0])
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Match today's weekday name to a CoachScheduleDay in the first saved schedule
    private func todayScheduleDay(from draft: CoachScheduleDraft?) -> CoachScheduleDay? {
        guard let draft else { return nil }
        let todayName = Calendar.current.weekdaySymbols[
            Calendar.current.component(.weekday, from: Date()) - 1
        ]   // "Monday", "Tuesday", …
        return draft.days.first { day in
            day.day.lowercased().hasPrefix(todayName.prefix(3).lowercased())
        }
    }

    // MARK: - Smart Plan

    private var smartPlanSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Label("AI Plan Generator", systemImage: "brain.head.profile")
                .font(.headline)
                .foregroundStyle(.primary)

            // Intensity selector
            HStack(spacing: DesignTokens.Spacing.sm) {
                ForEach(WorkoutIntensity.allCases) { intensity in
                    IntensityPill(
                        intensity: intensity,
                        isSelected: workoutVM.preferredIntensity == intensity
                    ) {
                        workoutVM.preferredIntensity = intensity
                    }
                }
            }

            // Duration stepper
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("Duration")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                Stepper("\(workoutVM.availableMinutes) min",
                        value: $workoutVM.availableMinutes,
                        in: 10...90,
                        step: 5)
                    .fixedSize()
            }
            .padding(DesignTokens.Spacing.sm)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

            // Generate button
            Button {
                workoutVM.generatePlan(store: store)
            } label: {
                HStack {
                    if workoutVM.isGeneratingPlan {
                        ProgressView().tint(.white).scaleEffect(0.85)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(workoutVM.isGeneratingPlan ? "Building your plan…" : "Generate Plan")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
                .background(workoutVM.isGeneratingPlan ? Color.orange.opacity(0.6) : Color.orange)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
            .disabled(workoutVM.isGeneratingPlan)

            if let err = workoutVM.planError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Generated plan card
            if let plan = workoutVM.currentPlan {
                Button {
                    selectedPlan = plan
                } label: {
                    GeneratedPlanCard(plan: plan)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text("Recommended For You")
                .font(.headline)
                .foregroundStyle(.primary)

            if workoutVM.recommendations.isEmpty {
                HStack {
                    ProgressView()
                    Text("Loading…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(DesignTokens.Spacing.md)
            } else {
                ForEach(workoutVM.recommendations) { rec in
                    Button {
                        path.append(rec)
                    } label: {
                        RecommendationCard(recommendation: rec)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Activity (Today / This Week)

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                Text("Activity")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Picker("", selection: $activityTab) {
                    ForEach(ActivityTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            let sessions = filteredSessions
            if sessions.isEmpty {
                Text("No workouts logged yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.Spacing.md)
            } else {
                activityStatsRow(sessions)
                ForEach(sessions.prefix(5)) { session in
                    SessionHistoryRow(session: session)
                }
            }
        }
    }

    private var filteredSessions: [WorkoutSession] {
        switch activityTab {
        case .today:
            let start = Calendar.current.startOfDay(for: Date())
            return store.workoutSessions
                .filter { $0.isCompleted && $0.startedAt >= start }
                .sorted { $0.startedAt > $1.startedAt }
        case .week:
            return store.recentSessions.sorted { $0.startedAt > $1.startedAt }
        }
    }

    private func activityStatsRow(_ sessions: [WorkoutSession]) -> some View {
        let totalCal = sessions.reduce(0.0) { $0 + $1.activeCaloriesBurned }
        let totalMin = sessions.reduce(0) { $0 + $1.durationSeconds / 60 }
        return HStack(spacing: DesignTokens.Spacing.sm) {
            ActivityStatChip(value: "\(sessions.count)", label: "sessions", icon: "figure.run")
            ActivityStatChip(
                value: Int(totalCal).formatted(),
                label: "kcal",
                icon: "flame.fill"
            )
            ActivityStatChip(value: "\(totalMin)", label: "min", icon: "clock.fill")
        }
    }
}

// MARK: - Schedule Library

struct ScheduleLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let schedules: [CoachScheduleDraft]
    let onAdd: () -> Void
    let onEdit: (CoachScheduleDraft) -> Void
    let onDelete: (CoachScheduleDraft) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                    if schedules.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 40))
                                .foregroundStyle(.orange)
                            Text("No saved schedules yet")
                                .font(.headline)
                            Text("Create one from AI Coach or start a custom draft here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Create Schedule") { onAdd() }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(DesignTokens.Spacing.md)
                                .background(.orange)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.lg)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    } else {
                        ForEach(schedules) { draft in
                            Button {
                                onEdit(draft)
                            } label: {
                                ScheduleSummaryCard(draft: draft)
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) {
                                    onDelete(draft)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Schedules")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onAdd()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Create schedule")
                }
            }
        }
    }
}

struct ScheduleSummaryCard: View {
    let draft: CoachScheduleDraft

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(draft.title)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                    Text(draft.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "calendar")
                    .foregroundStyle(.orange)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                CoachGoalChip(title: "Goal", value: draft.goal.focus)
                CoachGoalChip(title: "Level", value: draft.goal.fitnessLevel.rawValue)
            }
            HStack(spacing: DesignTokens.Spacing.xs) {
                CoachGoalChip(title: "Days", value: draft.goal.weeklySessions.formatted())
                CoachGoalChip(title: "Min", value: draft.goal.sessionMinutes.formatted())
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }
}

struct CoachScheduleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CoachScheduleDraft
    let onSave: (CoachScheduleDraft) -> Void
    init(initialDraft: CoachScheduleDraft, onSave: @escaping (CoachScheduleDraft) -> Void) {
        _draft = State(initialValue: initialDraft)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    editableCard(title: "Schedule Info") {
                        TextField("Title", text: $draft.title)
                        TextEditor(text: $draft.summary)
                            .frame(minHeight: 80)
                            .padding(DesignTokens.Spacing.xs)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                    }

                    editableCard(title: "Goal") {
                        TextField("Goal title", text: $draft.goal.title)
                        TextEditor(text: $draft.goal.summary)
                            .frame(minHeight: 80)
                            .padding(DesignTokens.Spacing.xs)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

                        Stepper("Daily calories: \(draft.goal.dailyCalorieGoal)", value: $draft.goal.dailyCalorieGoal, in: 100...5000, step: 50)
                        Stepper("Weekly sessions: \(draft.goal.weeklySessions)", value: $draft.goal.weeklySessions, in: 1...14)
                        Stepper("Session length: \(draft.goal.sessionMinutes) min", value: $draft.goal.sessionMinutes, in: 10...120, step: 5)

                        Picker("Fitness level", selection: $draft.goal.fitnessLevel) {
                            ForEach(FitnessLevel.allCases, id: \.self) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }

                        TextField("Focus", text: $draft.goal.focus)
                    }

                    editableCard(title: "Weekly Days") {
                        ForEach(draft.days.indices, id: \.self) { index in
                            ScheduleDayEditorRow(day: bindingForDay(at: index))
                        }

                        Button {
                            draft.days.append(.blank(day: "Day \(draft.days.count + 1)"))
                        } label: {
                            Label("Add Day", systemImage: "plus.circle.fill")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(DesignTokens.Spacing.sm)
                                .background(Color.orange.opacity(0.1))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                        }
                    }

                    Button {
                        onSave(draft)
                        dismiss()
                    } label: {
                        Label("Save Schedule", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(DesignTokens.Spacing.md)
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Edit Schedule")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func editableCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            content()
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    private func bindingForDay(at index: Int) -> Binding<CoachScheduleDay> {
        Binding(
            get: { draft.days[index] },
            set: { draft.days[index] = $0 }
        )
    }
}

private struct CoachGoalChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}

struct ScheduleDayEditorRow: View {
    @Binding var day: CoachScheduleDay

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            TextField("Day", text: $day.day)
                .font(.subheadline.bold())
            TextField("Focus", text: $day.focus)
            HStack {
                Stepper("\(day.durationMinutes) min", value: $day.durationMinutes, in: 10...180, step: 5)
                Spacer()
                Picker("Intensity", selection: $day.intensity) {
                    ForEach(WorkoutIntensity.allCases) { intensity in
                        Text(intensity.rawValue).tag(intensity)
                    }
                }
                .pickerStyle(.menu)
            }
            TextField("Exercises (comma separated)", text: Binding(
                get: { day.exercises.joined(separator: ", ") },
                set: { day.exercises = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
            ))
            TextEditor(text: $day.note)
                .frame(minHeight: 70)
                .padding(.horizontal, DesignTokens.Spacing.xs)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .padding(DesignTokens.Spacing.sm)
        .background(Color(.systemGray6).opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}

// MARK: - IntensityPill

struct IntensityPill: View {
    let intensity: WorkoutIntensity
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: intensity.systemImage)
                    .font(.subheadline)
                Text(intensity.rawValue)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(isSelected ? Color.orange : Color(.systemGray5))
            .foregroundStyle(isSelected ? .white : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - GeneratedPlanCard

struct GeneratedPlanCard: View {
    let plan: WorkoutPlan

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: plan.intensity.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(Color.orange)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(plan.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Text("\(plan.durationMinutes) min · \(plan.estimatedCaloriesFormatted) kcal est.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(plan.exercises.count) exercises · \(plan.intensity.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.5), lineWidth: 1.5)
        )
    }
}

// MARK: - ActivityStatChip

struct ActivityStatChip: View {
    let value: String
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, DesignTokens.Spacing.xs)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}

// MARK: - RecommendationCard

struct RecommendationCard: View {
    let recommendation: WorkoutRecommendation

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Image(systemName: recommendation.type.systemImage)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.orange)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(recommendation.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("\(recommendation.durationMinutes) min · \(recommendation.difficulty.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(recommendation.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }
}

// MARK: - SessionHistoryRow

struct SessionHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            Image(systemName: session.workoutType.systemImage)
                .foregroundStyle(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(session.workoutType.rawValue)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(session.startedAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
                Text(session.activeCaloriesBurned.formatted(.number.precision(.fractionLength(0))) + " kcal")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                Text(session.durationFormatted)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.sm)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
    }
}

// MARK: - TodayScheduleDayCard

struct TodayScheduleDayCard: View {
    let day: CoachScheduleDay

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today · \(day.day)")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                    Text(day.focus)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.durationMinutes) min")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(day.intensity.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if !day.exercises.isEmpty {
                Text(day.exercises.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !day.note.isEmpty {
                Label(day.note, systemImage: "lightbulb.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Hashable conformance for NavigationStack destination

extension WorkoutRecommendation: Hashable {
    public static func == (lhs: WorkoutRecommendation, rhs: WorkoutRecommendation) -> Bool {
        lhs.id == rhs.id
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
