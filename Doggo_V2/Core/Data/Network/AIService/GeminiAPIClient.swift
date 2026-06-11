import Foundation

final class GeminiAPIClient: AIClientProtocol {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"

    init() {}

    func sendRequest(prompt: String) async throws -> String {
        let apiKey = try AIClientSupport.key(for: .gemini)

        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await AIClientSupport.makeSession().data(for: request)
        try AIClientSupport.validate(response)

        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let candidates = json["candidates"] as? [[String: Any]],
           let content = candidates.first?["content"] as? [String: Any],
           let parts = content["parts"] as? [[String: Any]],
           let text = parts.first?["text"] as? String {
            return text
        }

        throw APIError.parseError
    }
}

enum APIError: LocalizedError {
    case missingKey
    case invalidKey
    case invalidURL
    case rateLimitExceeded
    case httpError(statusCode: Int)
    case parseError

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "⚠️ No API Key for \(AIProvider.current.label). Add one in Settings → AI Coach."
        case .invalidKey:
            return "⚠️ The \(AIProvider.current.label) API Key was rejected. Check it in Settings → AI Coach."
        case .invalidURL:
            return "Invalid URL"
        case .rateLimitExceeded:
            return "⚠️ The Coach is busy (Rate Limit). Please try again in a minute."
        case .httpError(let code):
            return "Server error: \(code)"
        case .parseError:
            return "Failed to parse response"
        }
    }
}
