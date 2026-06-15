//
//  OpenRouterAPIClient.swift
//  Doggo_V2
//
//  OpenRouter (openrouter.ai) — an OpenAI-compatible gateway that routes to
//  hundreds of models. The model slug is user-configurable in Settings
//  (e.g. "anthropic/claude-sonnet-4.5", "google/gemini-2.5-pro");
//  "openrouter/auto" lets OpenRouter pick automatically.
//

import Foundation

final class OpenRouterAPIClient: AIClientProtocol {
    private let endpoint = "https://openrouter.ai/api/v1/chat/completions"

    static let defaultModel = "openrouter/auto"

    /// The model slug selected in Settings.
    static var model: String {
        let stored = UserDefaults.standard.string(forKey: "openRouterModel") ?? ""
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultModel : trimmed
    }

    func sendRequest(prompt: String) async throws -> String {
        let apiKey = try AIClientSupport.key(for: .openrouter)

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        // Attribution headers — recommended by OpenRouter for activity ranking.
        request.addValue("Doggo", forHTTPHeaderField: "X-Title")
        request.addValue("https://doggo.app", forHTTPHeaderField: "HTTP-Referer")

        let body: [String: Any] = [
            "model": Self.model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIClientSupport.makeSession().data(for: request)

        // OpenRouter encodes the *reason* in the response body (free-model
        // daily/minute caps, an upstream provider error, etc.). Read it before
        // throwing so the user sees the actual cause, not a generic message.
        let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            switch http.statusCode {
            case 401, 403:
                throw APIError.invalidKey
            case 429:
                // `:free` models are capped at ~20 req/min and 50/day (1000/day
                // with ≥$10 of credits); the body usually says which.
                throw APIError.rateLimited(
                    detail: serverMessage ?? "OpenRouter throttled this model. Free (:free) models have tight per-minute and daily caps — switch to the paid model slug or add credits."
                )
            default:
                throw APIError.providerError(
                    message: serverMessage ?? "OpenRouter request failed",
                    statusCode: http.statusCode
                )
            }
        }

        // OpenAI-compatible success:
        // { "choices": [ { "message": { "content": "..." } } ] }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let text = message["content"] as? String,
           !text.isEmpty {
            return text
        }

        // Some routing/model errors arrive with a 200 status but an "error"
        // object instead of choices — surface that message too.
        if let serverMessage {
            throw APIError.providerError(message: serverMessage, statusCode: 200)
        }

        throw APIError.parseError
    }
}
