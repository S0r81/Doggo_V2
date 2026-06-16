//
//  AIProvider.swift
//  Doggo_V2
//
//  Multi-provider AI support. Prompts and response parsing are provider-
//  agnostic (plain text in/out), so each provider only needs an HTTP client.
//

import Foundation

// MARK: - Provider

enum AIProvider: String, CaseIterable, Identifiable {
    case gemini
    case anthropic
    case openai
    case openrouter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .anthropic: return "Anthropic Claude"
        case .openai: return "OpenAI GPT"
        case .openrouter: return "OpenRouter"
        }
    }

    var shortLabel: String {
        switch self {
        case .gemini: return "Gemini"
        case .anthropic: return "Claude"
        case .openai: return "GPT"
        case .openrouter: return "OpenRouter"
        }
    }

    /// Keychain account name. Gemini keeps the legacy account so existing
    /// saved keys keep working after the update.
    var keychainAccount: String {
        switch self {
        case .gemini: return "gemini_api_key"
        case .anthropic: return "anthropic_api_key"
        case .openai: return "openai_api_key"
        case .openrouter: return "openrouter_api_key"
        }
    }

    var keyPlaceholder: String {
        switch self {
        case .gemini: return "Enter Gemini API Key (AIza…)"
        case .anthropic: return "Enter Anthropic API Key (sk-ant-…)"
        case .openai: return "Enter OpenAI API Key (sk-…)"
        case .openrouter: return "Enter OpenRouter API Key (sk-or-…)"
        }
    }

    var keyHelpText: String {
        switch self {
        case .gemini: return "Get a key at aistudio.google.com"
        case .anthropic: return "Get a key at platform.claude.com"
        case .openai: return "Get a key at platform.openai.com"
        case .openrouter: return "Get a key at openrouter.ai"
        }
    }

    /// The provider currently selected in Settings.
    static var current: AIProvider {
        let raw = UserDefaults.standard.string(forKey: "aiProvider") ?? AIProvider.gemini.rawValue
        return AIProvider(rawValue: raw) ?? .gemini
    }
}

// MARK: - Client Protocol

protocol AIClientProtocol {
    func sendRequest(prompt: String) async throws -> String
}

// MARK: - Router

/// Resolves the selected provider at request time, so changing the setting
/// takes effect immediately without rebuilding the AppContainer.
final class AIClientRouter: AIClientProtocol {
    private let gemini = GeminiAPIClient()
    private let anthropic = AnthropicAPIClient()
    private let openai = OpenAIAPIClient()
    private let openrouter = OpenRouterAPIClient()

    func sendRequest(prompt: String) async throws -> String {
        switch AIProvider.current {
        case .gemini: return try await gemini.sendRequest(prompt: prompt)
        case .anthropic: return try await anthropic.sendRequest(prompt: prompt)
        case .openai: return try await openai.sendRequest(prompt: prompt)
        case .openrouter: return try await openrouter.sendRequest(prompt: prompt)
        }
    }
}

// MARK: - Shared Helpers

enum AIClientSupport {
    /// One shared session (connection pooling + TLS reuse). Generous timeouts —
    /// routine/program generation can be slow.
    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }()

    static func key(for provider: AIProvider) throws -> String {
        guard let key = KeychainManager.shared.retrieveKey(for: provider), !key.isEmpty else {
            throw APIError.missingKey
        }
        return key
    }

    /// Sends a request and parses it, with uniform error handling for ALL
    /// providers. Every client just builds the request and supplies a `parse`
    /// closure — so improvements (like surfacing the provider's real error
    /// message) apply everywhere instead of one client at a time.
    ///
    /// Gemini / OpenAI / Anthropic / OpenRouter all report failures as
    /// `{ "error": { "message": "..." } }`, so one extractor covers them.
    static func execute(_ request: URLRequest, parse: (Data) -> String?) async throws -> String {
        let (data, response) = try await session.data(for: request)

        let serverMessage = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
            .flatMap { ($0?["error"] as? [String: Any])?["message"] as? String }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            switch http.statusCode {
            case 401, 403:
                throw APIError.invalidKey
            case 429:
                throw APIError.rateLimited(
                    detail: serverMessage ?? "\(AIProvider.current.label) is throttling requests. Wait a minute, or switch model/provider in Settings."
                )
            default:
                throw APIError.providerError(
                    message: serverMessage ?? "\(AIProvider.current.label) request failed",
                    statusCode: http.statusCode
                )
            }
        }

        if let text = parse(data), !text.isEmpty { return text }
        // 200 with an error object instead of content.
        if let serverMessage { throw APIError.providerError(message: serverMessage, statusCode: 200) }
        throw APIError.parseError
    }
}
