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

        // The shared executor reads OpenRouter's error body and surfaces the
        // real reason (free-model caps, upstream errors). Response is
        // OpenAI-compatible: { "choices": [ { "message": { "content": "..." } } ] }.
        return try await AIClientSupport.execute(request) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any] else { return nil }
            return message["content"] as? String
        }
    }
}
