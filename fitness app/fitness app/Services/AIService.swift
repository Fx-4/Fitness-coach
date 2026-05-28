import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String   // "user" | "assistant" | "system"
    let content: String

    init(role: String, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
    }
}

// MARK: - AI Service (Groq)
// ─────────────────────────────────────────────────────────
// Ganti API key di bawah ini dengan key Groq kamu:
//   https://console.groq.com/keys
// ─────────────────────────────────────────────────────────

final class AIService {
    static let shared = AIService()

    private let apiKey = "YOUR_GROQ_API_KEY_HERE"   // ← paste key Groq kamu di sini (dari https://console.groq.com/keys)
    private let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    private let model = "llama-3.1-8b-instant"   // model Groq tercepat & gratis

    private init() {}

    func chat(messages: [ChatMessage]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("FitCoach iOS", forHTTPHeaderField: "HTTP-Referer")
        request.timeoutInterval = 30

        let payload: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] }
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else { throw AIError.requestFailed }
        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.httpError(http.statusCode, body)
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let msg = choices.first?["message"] as? [String: Any],
            let content = msg["content"] as? String
        else {
            throw AIError.invalidResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func improveText(_ text: String, hint: String = "workout note") async throws -> String {
        let messages = [
            ChatMessage(
                role: "system",
                content: "You are a writing assistant for a fitness app. Improve the user's text to be clear, specific, and motivating while preserving its meaning. Reply with ONLY the improved text — no explanation, no quotation marks."
            ),
            ChatMessage(role: "user", content: "Improve this \(hint):\n\n\(text)")
        ]
        return try await chat(messages: messages)
    }

    enum AIError: LocalizedError {
        case requestFailed
        case httpError(Int, String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .requestFailed:
                return "Network request failed. Check your internet connection."
            case .httpError(401, _), .httpError(403, _):
                return "Invalid API key. Paste your Groq key at console.groq.com/keys."
            case .httpError(429, _):
                return "Rate limit reached. Wait a moment and try again."
            case .httpError(let c, _):
                return "Server error \(c). Try again later."
            case .invalidResponse:
                return "Could not parse AI response."
            }
        }
    }
}
