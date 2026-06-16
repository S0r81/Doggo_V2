//
//  AnthropicAPIClient.swift
//  Doggo_V2
//
//  Claude via the Anthropic Messages API (POST /v1/messages).
//

import Foundation

final class AnthropicAPIClient: AIClientProtocol {
    private let endpoint = "https://api.anthropic.com/v1/messages"
    private let model = "claude-opus-4-8"

    func sendRequest(prompt: String) async throws -> String {
        let apiKey = try AIClientSupport.key(for: .anthropic)

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Response: { "content": [ { "type": "text", "text": "..." }, ... ] }
        // Concatenate all text blocks (thinking blocks etc. are skipped).
        return try await AIClientSupport.execute(request) { data in
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]] else { return nil }
            return content
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined()
        }
    }
}
