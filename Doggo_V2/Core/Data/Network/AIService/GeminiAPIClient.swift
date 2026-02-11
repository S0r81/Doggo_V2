import Foundation

final class GeminiAPIClient {
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent"
    
    init() {}
    
    func sendRequest(prompt: String) async throws -> String {
        // 1. Fetch Key from Keychain
        guard let apiKey = KeychainManager.shared.retrieveKey(), !apiKey.isEmpty else {
            throw APIError.missingKey
        }
        
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["contents": [["parts": [["text": prompt]]]]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // 180 second timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                throw APIError.rateLimitExceeded
            }
            if httpResponse.statusCode != 200 {
                print("Gemini API Error: \(httpResponse.statusCode)")
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }
        }
        
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
    case invalidURL
    case rateLimitExceeded
    case httpError(statusCode: Int)
    case parseError
    
    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "⚠️ API Key Missing. Please add your Gemini API Key in Settings."
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
