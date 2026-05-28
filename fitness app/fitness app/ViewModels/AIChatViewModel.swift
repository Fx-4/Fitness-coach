import SwiftUI

@MainActor
final class AIChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft = ""
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var canGenerateScheduleDraft = false
    @Published var generatedScheduleDraft: CoachScheduleDraft? = nil
    @Published var isGeneratingScheduleDraft = false
    @Published var scheduleDraftError: String? = nil

    private var lastUserRequest = ""

    private let systemPrompt = """
    You are FitCoach AI, a concise and encouraging personal fitness coach. Help users with:
    - Workout plans and exercise selection
    - Exercise form and technique tips
    - Recovery, rest, and sleep advice
    - Basic nutrition guidance (not medical advice)
    - Motivation, habits, and goal-setting
    Keep answers short, practical, and encouraging. For medical concerns, always recommend consulting a doctor.
    """

    private let schedulePromptSuffix = """
    If the user asks for a workout schedule, routine, plan, or weekly program, answer with a short recommendation and invite them to press Generate Schedule. Do not generate the full week plan in this response.
    """

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        draft = ""
        errorMessage = nil
        scheduleDraftError = nil
        lastUserRequest = text
        messages.append(ChatMessage(role: "user", content: text))
        isLoading = true

        let history = buildHistory(for: text)

        do {
            let reply = try await AIService.shared.chat(messages: history)
            messages.append(ChatMessage(role: "assistant", content: reply))
            canGenerateScheduleDraft = shouldOfferScheduleDraft(for: text)
            if !canGenerateScheduleDraft {
                generatedScheduleDraft = nil
            } else {
                generatedScheduleDraft = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            messages.removeLast()
            draft = text
        }
        isLoading = false
    }

    func generateScheduleDraft(profile: UserProfile) async {
        guard generatedScheduleDraft == nil, canGenerateScheduleDraft else { return }

        isGeneratingScheduleDraft = true
        scheduleDraftError = nil

        do {
            let draft = try await buildCoachScheduleDraft(
                messages: buildHistory(for: lastUserRequest),
                profile: profile,
                requestText: lastUserRequest
            )
            generatedScheduleDraft = draft
            canGenerateScheduleDraft = false
        } catch {
            scheduleDraftError = error.localizedDescription
        }

        isGeneratingScheduleDraft = false
    }

    func approveScheduleDraft(store: AppDataStore) {
        guard let draft = generatedScheduleDraft else { return }
        store.approveCoachSchedule(draft)
        messages.append(ChatMessage(role: "assistant", content: "Schedule saved. I updated your goal and stored the plan in Workouts."))
        generatedScheduleDraft = nil
        scheduleDraftError = nil
        canGenerateScheduleDraft = false
    }

    func clear() {
        messages.removeAll()
        errorMessage = nil
        scheduleDraftError = nil
        canGenerateScheduleDraft = false
        generatedScheduleDraft = nil
    }

    func clearScheduleDraft() {
        generatedScheduleDraft = nil
        scheduleDraftError = nil
        canGenerateScheduleDraft = false
    }

    private func buildHistory(for userText: String) -> [ChatMessage] {
        let prompt = shouldOfferScheduleDraft(for: userText) ? systemPrompt + "\n\n" + schedulePromptSuffix : systemPrompt
        return [ChatMessage(role: "system", content: prompt)] + messages
    }

    private func shouldOfferScheduleDraft(for text: String) -> Bool {
        let query = text.lowercased()
        return ["schedule", "jadwal", "program", "routine", "weekly", "mingguan", "workout split", "plan olahraga"].contains { query.contains($0) }
    }

    // MARK: - Schedule draft builder

    private func buildCoachScheduleDraft(
        messages: [ChatMessage],
        profile: UserProfile,
        requestText: String
    ) async throws -> CoachScheduleDraft {
        let jsonInstruction = """
        Based on our conversation, generate a personalized weekly workout schedule.

        User profile:
        - Fitness level: \(profile.fitnessLevel.rawValue)
        - Age: \(profile.age)
        - Weight: \(profile.weightKg) kg
        - Daily calorie goal: \(profile.dailyCalorieGoal) kcal

        Respond with ONLY raw JSON (no markdown, no code fences, no extra text). Use this exact shape:
        {
          "reply": "short encouraging message",
          "draft": {
            "id": "00000000-0000-0000-0000-000000000001",
            "title": "schedule title",
            "summary": "one-sentence summary",
            "goal": {
              "id": "00000000-0000-0000-0000-000000000002",
              "title": "goal title",
              "summary": "goal summary",
              "dailyCalorieGoal": \(profile.dailyCalorieGoal),
              "weeklySessions": 4,
              "sessionMinutes": 45,
              "fitnessLevel": "\(profile.fitnessLevel.rawValue)",
              "focus": "focus area e.g. strength, weight loss"
            },
            "days": [
              {
                "id": "00000000-0000-0000-0000-000000000003",
                "day": "Monday",
                "focus": "Upper body strength",
                "durationMinutes": 45,
                "intensity": "Moderate",
                "exercises": ["Push-Up", "Dumbbell Row", "Shoulder Press"],
                "note": "Keep form strict on each rep"
              }
            ]
          }
        }
        intensity must be one of: "Light", "Moderate", "Vigorous"
        fitnessLevel must be one of: "Beginner", "Intermediate", "Advanced"
        Include 3-5 training days. No rest days needed.
        """

        var buildMessages = messages
        buildMessages.append(ChatMessage(role: "user", content: jsonInstruction))

        let raw = try await AIService.shared.chat(messages: buildMessages)
        let cleaned = Self.extractJSON(from: raw)

        guard let data = cleaned.data(using: .utf8) else {
            throw AIService.AIError.invalidResponse
        }

        let decoder = JSONDecoder()
        if let response = try? decoder.decode(CoachScheduleResponse.self, from: data) {
            return response.draft
        }
        if let directDraft = try? decoder.decode(CoachScheduleDraft.self, from: data) {
            return directDraft
        }
        throw AIService.AIError.invalidResponse
    }

    private static func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences
        if s.hasPrefix("```") {
            let lines = s.components(separatedBy: "\n")
            s = lines.dropFirst().dropLast().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Grab content between first { and last }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s
    }
}
