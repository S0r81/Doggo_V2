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
    /// Session with generous timeouts — routine generation can be slow.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 180
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }

    static func key(for provider: AIProvider) throws -> String {
        guard let key = KeychainManager.shared.retrieveKey(for: provider), !key.isEmpty else {
            throw APIError.missingKey
        }
        return key
    }

    static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 429 { throw APIError.rateLimitExceeded }
        if http.statusCode == 401 || http.statusCode == 403 { throw APIError.invalidKey }
        if http.statusCode != 200 {
            print("\(AIProvider.current.label) API Error: \(http.statusCode)")
            throw APIError.httpError(statusCode: http.statusCode)
        }
    }
}
