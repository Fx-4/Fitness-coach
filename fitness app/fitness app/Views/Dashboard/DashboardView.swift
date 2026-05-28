import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: AppDataStore
    @StateObject private var viewModel = DashboardViewModel()
    @State private var showingGoalSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {

                    // 1. Greeting + health connection status pill
                    greetingRow

                    // 2. Compact action banner — only when user must act
                    actionBanner

                    // 3. Hero card — calories + progress % + daily goal
                    activeEnergyCard

                    // 4. Quick stats — steps + goal target
                    quickStatsRow

                    // 5. Today's schedule (if user has a saved schedule)
                    todayScheduleCard

                    // 6. Recommendation entry point
                    suggestionsEntryCard

                    // 6. Weekly chart (when data available)
                    if !viewModel.weeklyCalories.isEmpty {
                        WeeklyBarChart(
                            samples: viewModel.weeklyCalories,
                            goal: Double(viewModel.dailyCalorieGoal)
                        )
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Today")
            .toolbar { toolbarContent }
            .task {
                viewModel.updateGoal(from: store.profile)
                await viewModel.loadHealthData()
            }
            .refreshable { await viewModel.loadHealthData() }
            .sheet(isPresented: $showingGoalSheet) {
                CalorieGoalSheet(viewModel: viewModel, store: store)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isLoadingHealth {
                ProgressView().scaleEffect(0.8)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button {
                    Task { await viewModel.loadHealthData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .accessibilityLabel("Refresh health data")
                }
                .disabled(viewModel.isLoadingHealth)

                Button {
                    showingGoalSheet = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .accessibilityLabel("Set daily calorie goal")
                }
            }
        }
    }

    // MARK: - 1. Greeting row + health status pill

    private var greetingRow: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(greeting)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(Date().formatted(.dateTime.weekday(.wide).month().day()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HealthStatusPill(status: viewModel.healthStatus)
        }
    }

    // MARK: - 2. Action banner (only notDetermined / denied)

    @ViewBuilder
    private var actionBanner: some View {
        switch viewModel.healthStatus {
        case .notDetermined:
            StatusBanner(
                icon: "heart.fill",
                color: .red,
                title: "Connect Apple Health",
                message: "Allow access so FitCoach can read your active energy and steps.",
                actionLabel: "Grant Access",
                action: { Task { await viewModel.requestPermission() } }
            )
        case .denied:
            StatusBanner(
                icon: "exclamationmark.triangle.fill",
                color: .orange,
                title: "Health Access Off",
                message: "Settings → Privacy & Security → Health → FitCoach to turn it back on.",
                actionLabel: "Open Settings",
                action: {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            )
        case .unavailable, .authorized:
            EmptyView()
        }
    }

    // MARK: - 3. Hero card

    private var activeEnergyCard: some View {
        VStack(spacing: DesignTokens.Spacing.md) {

            // Goal header
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Energy")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Daily goal: \(viewModel.dailyCalorieGoal) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button { showingGoalSheet = true } label: {
                    Text("Edit Goal")
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
                }
                .accessibilityLabel("Edit daily goal, currently \(viewModel.dailyCalorieGoal) kcal")
            }

            // Progress ring
            HStack {
                Spacer()
                CalorieRingView(
                    progress: viewModel.activeEnergyProgress,
                    burned: viewModel.activeEnergyFormatted,
                    goal: viewModel.goalFormatted
                )
                Spacer()
            }

            // Progress percentage summary
            progressSummary

            // Error message (pull to refresh hint)
            if let error = viewModel.healthError {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    @ViewBuilder
    private var progressSummary: some View {
        if viewModel.activeEnergyProgress >= 1 {
            Label("Daily goal reached!", systemImage: "checkmark.seal.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)
        } else if viewModel.healthStatus == .authorized && viewModel.activeEnergyToday == 0 {
            VStack(spacing: DesignTokens.Spacing.xs) {
                Image(systemName: "figure.walk.motion")
                    .font(.title3).foregroundStyle(.secondary)
                Text("No activity recorded yet today.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("Start moving and it will appear here.")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
        } else {
            // Progress percentage — prominent, practical
            HStack(spacing: DesignTokens.Spacing.sm) {
                ProgressPill(value: Int(viewModel.activeEnergyProgress * 100))
                Text("of \(viewModel.dailyCalorieGoal) kcal goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 4. Quick stats

    private var quickStatsRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ActivityCard(
                title: "Steps",
                value: viewModel.stepCountFormatted,
                unit: "steps today",
                systemImage: "figure.walk",
                tint: .blue
            )
            ActivityCard(
                title: "Goal",
                value: viewModel.goalFormatted,
                unit: "kcal target",
                systemImage: "target",
                tint: .orange
            )
        }
    }

    // MARK: - 5. Today's Schedule Card

    @ViewBuilder
    private var todayScheduleCard: some View {
        if let schedule = store.savedCoachSchedules.first ?? store.approvedCoachSchedule,
           let todayDay = matchTodayDay(in: schedule) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label("Today's Plan", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)

                HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(todayDay.focus)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(todayDay.exercises.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(todayDay.durationMinutes) min")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                        Text(todayDay.intensity.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DesignTokens.Spacing.md)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
            )
        }
    }

    private func matchTodayDay(in draft: CoachScheduleDraft) -> CoachScheduleDay? {
        let todayName = Calendar.current.weekdaySymbols[
            Calendar.current.component(.weekday, from: Date()) - 1
        ]
        return draft.days.first { day in
            day.day.lowercased().hasPrefix(todayName.prefix(3).lowercased())
        }
    }

    // MARK: - 6. Recommendation entry point

    private var suggestionsEntryCard: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.yellow)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Today's Suggestions")
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text("Sessions tailored to your recent activity")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(Color.yellow.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }

    // MARK: - Helpers

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let name = store.profile.name.isEmpty ? "" : ", \(store.profile.name)"
        switch hour {
        case 0..<12:  return "Good morning\(name)!"
        case 12..<17: return "Good afternoon\(name)!"
        default:      return "Good evening\(name)!"
        }
    }
}

// MARK: - Health Status Pill

private struct HealthStatusPill: View {
    let status: HealthStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.sm)
        .padding(.vertical, 5)
        .background(dotColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
    }

    private var dotColor: Color {
        switch status {
        case .authorized:    return .green
        case .unavailable:   return .gray
        case .notDetermined: return .orange
        case .denied:        return .red
        }
    }

    private var label: String {
        switch status {
        case .authorized:    return "Health On"
        case .unavailable:   return "Sample Data"
        case .notDetermined: return "Connect Health"
        case .denied:        return "Access Off"
        }
    }
}

// MARK: - Progress Pill

private struct ProgressPill: View {
    let value: Int

    var body: some View {
        Text("\(value)%")
            .font(.caption.bold())
            .foregroundStyle(.orange)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
    }
}

// MARK: - Status Banner

struct StatusBanner: View {
    let icon: String
    let color: Color
    let title: String
    let message: String
    let actionLabel: String?
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let label = actionLabel, let action {
                    Button(label, action: action)
                        .font(.caption.bold())
                        .foregroundStyle(color)
                        .padding(.top, 2)
                }
            }
            Spacer()
        }
        .padding(DesignTokens.Spacing.md)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
    }
}

// MARK: - Calorie Goal Sheet

struct CalorieGoalSheet: View {
    @ObservedObject var viewModel: DashboardViewModel
    @ObservedObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @State private var tempGoal: Double

    init(viewModel: DashboardViewModel, store: AppDataStore) {
        self.viewModel = viewModel
        self.store = store
        _tempGoal = State(initialValue: Double(viewModel.dailyCalorieGoal))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignTokens.Spacing.xl) {

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Text("\(Int(tempGoal))")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .animation(.spring(response: 0.3), value: tempGoal)
                    Text("kcal / day")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DesignTokens.Spacing.xl)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    Slider(value: $tempGoal, in: 100...1500, step: 50)
                        .accentColor(.orange)
                    HStack {
                        Text("100").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("1500 kcal").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)

                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(presets, id: \.label) { preset in
                        Button {
                            withAnimation { tempGoal = preset.value }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.label)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Text(preset.description)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Int(preset.value)) kcal")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.orange)
                                if Int(tempGoal) == Int(preset.value) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.orange)
                                        .font(.caption.bold())
                                }
                            }
                            .padding(DesignTokens.Spacing.md)
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)

                Spacer()
            }
            .navigationTitle("Daily Calorie Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.dailyCalorieGoal = Int(tempGoal)
                        store.profile.dailyCalorieGoal = Int(tempGoal)
                        dismiss()
                    }
                    .bold()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private struct Preset {
        let label: String
        let description: String
        let value: Double
    }

    private let presets: [Preset] = [
        Preset(label: "Light",    description: "Short walk or gentle movement",  value: 300),
        Preset(label: "Moderate", description: "Active daily routine",            value: 500),
        Preset(label: "Active",   description: "Regular gym or sport sessions",   value: 700),
        Preset(label: "Intense",  description: "High-volume daily training",      value: 1000),
    ]
}
