//
//  OpenAIAPIClient.swift
//  Doggo_V2
//
//  GPT via the OpenAI Chat Completions API.
//

import Foundation

final class OpenAIAPIClient: AIClientProtocol {
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-5"

    func sendRequest(prompt: String) async throws -> String {
        let apiKey = try AIClientSupport.key(for: .openai)

        guard let url = URL(string: endpoint) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIClientSupport.makeSession().data(for: request)
        try AIClientSupport.validate(response)

        // Response: { "choices": [ { "message": { "content": "..." } } ] }
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let text = message["content"] as? String,
           !text.isEmpty {
            return text
        }

        throw APIError.parseError
    }
}
