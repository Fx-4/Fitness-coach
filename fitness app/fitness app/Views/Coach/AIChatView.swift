import SwiftUI

struct AIChatView: View {
    @StateObject private var vm = AIChatViewModel()
    @EnvironmentObject private var store: AppDataStore
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messageList
                scheduleActionArea
                inputBar
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !vm.messages.isEmpty {
                        Button("Clear") { vm.clear() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DesignTokens.Spacing.sm) {
                    if vm.messages.isEmpty {
                        emptyState
                            .padding(.top, DesignTokens.Spacing.xxl)
                    }
                    ForEach(vm.messages) { msg in
                        MessageBubble(message: msg)
                            .id(msg.id)
                    }
                    if vm.isLoading {
                        TypingDots()
                            .id("typing")
                    }
                }
                .padding(DesignTokens.Spacing.md)
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.isLoading) { loading in
                if loading {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("typing", anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.generatedScheduleDraft?.id) { _ in
                if let last = vm.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Schedule Action

    private var scheduleActionArea: some View {
        Group {
            if let draft = vm.generatedScheduleDraft {
                CoachScheduleDraftCard(
                    draft: draft,
                    onApprove: { vm.approveScheduleDraft(store: store) },
                    onClose: { vm.clearScheduleDraft() }
                )
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.sm)
            } else if vm.canGenerateScheduleDraft {
                VStack(spacing: DesignTokens.Spacing.xs) {
                    Button {
                        Task { await vm.generateScheduleDraft(profile: store.profile) }
                    } label: {
                        HStack {
                            if vm.isGeneratingScheduleDraft {
                                ProgressView().tint(.white).scaleEffect(0.85)
                            } else {
                                Image(systemName: "calendar.badge.plus")
                            }
                            Text(vm.isGeneratingScheduleDraft ? "Building schedule…" : "Generate Schedule")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.Spacing.md)
                        .background(vm.isGeneratingScheduleDraft ? Color.orange.opacity(0.6) : Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    }
                    .disabled(vm.isGeneratingScheduleDraft)

                    if let error = vm.scheduleDraftError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.top, DesignTokens.Spacing.sm)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 52))
                .foregroundStyle(.orange)

            VStack(spacing: DesignTokens.Spacing.xs) {
                Text("FitCoach AI")
                    .font(.title2.bold())
                Text("Ask me anything about workouts,\nform, nutrition, or recovery.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(suggestions, id: \.self) { s in
                    Button {
                        vm.draft = s
                        Task { await vm.send() }
                    } label: {
                        Text(s)
                            .font(.subheadline)
                            .padding(.horizontal, DesignTokens.Spacing.md)
                            .padding(.vertical, DesignTokens.Spacing.sm)
                            .frame(maxWidth: .infinity)
                            .background(Color.orange.opacity(0.1))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.xl)
    }

    private let suggestions = [
        "Best beginner full-body workout?",
        "How to improve squat form?",
        "Foods to eat after a workout?",
    ]

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            if let err = vm.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.top, DesignTokens.Spacing.xs)
            }
            Divider()
            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
                TextField("Ask your coach…", text: $vm.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs + 2)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
                    .focused($focused)

                Button {
                    focused = false
                    Task { await vm.send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading
                            ? Color.secondary : Color.orange
                        )
                }
                .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
        }
        .background(.regularMaterial)
    }
}

// MARK: - CoachScheduleDraftCard

struct CoachScheduleDraftCard: View {
    let draft: CoachScheduleDraft
    let onApprove: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(draft.title)
                        .font(.headline.bold())
                    Text(draft.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss schedule draft")
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(draft.goal.title)
                    .font(.subheadline.bold())
                Text(draft.goal.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                CoachGoalChip(title: "Goal", value: draft.goal.focus)
                CoachGoalChip(title: "Level", value: draft.goal.fitnessLevel.rawValue)
            }

            HStack(spacing: DesignTokens.Spacing.xs) {
                CoachGoalChip(title: "Kcal", value: draft.goal.dailyCalorieGoal.formatted())
                CoachGoalChip(title: "Days", value: draft.goal.weeklySessions.formatted())
                CoachGoalChip(title: "Min", value: draft.goal.sessionMinutes.formatted())
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text("Weekly Outline")
                    .font(.subheadline.bold())
                ForEach(draft.days) { day in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(day.day)
                                .font(.caption.bold())
                            Spacer()
                            Text(day.durationMinutes.formatted() + " min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(day.focus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(day.exercises.joined(separator: " • "))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }

            Button(action: onApprove) {
                Label("Approve & Save", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(DesignTokens.Spacing.md)
                    .background(Color.green)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))
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

// MARK: - MessageBubble

struct MessageBubble: View {
    let message: ChatMessage
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
            if isUser { Spacer(minLength: 56) }

            if !isUser {
                Image(systemName: "brain.head.profile")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(Color.orange)
                    .clipShape(Circle())
            }

            Text(message.content)
                .font(.body)
                .foregroundStyle(isUser ? .white : .primary)
                .padding(.horizontal, DesignTokens.Spacing.md)
                .padding(.vertical, DesignTokens.Spacing.sm)
                .background(isUser ? Color.orange : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

            if !isUser { Spacer(minLength: 56) }
        }
    }
}

// MARK: - TypingDots

struct TypingDots: View {
    @State private var animate = false

    var body: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.xs) {
            Image(systemName: "brain.head.profile")
                .font(.caption2)
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Color.orange)
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color(.systemGray3))
                        .frame(width: 8, height: 8)
                        .offset(y: animate ? -5 : 0)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.sm)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous))

            Spacer(minLength: 56)
        }
        .onAppear { animate = true }
    }
}
