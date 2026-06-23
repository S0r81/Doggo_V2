//
//  CoachChatEngine.swift
//  Doggo_V2
//
//  Turns a user chat message into a Coach reply. It assembles the shared prompt
//  (data grounding + standing context + recent turns) and sends it through the
//  EXISTING client protocol — the same AIClientRouter / AIClientSupport.execute
//  path the report uses. No second networking path: all four providers, the
//  per-provider Keychain keys, and APIError handling work unchanged.
//

import Foundation

enum CoachChatEngine {

    /// Sends one chat turn and returns the assistant's reply text.
    /// Errors (missingKey / invalidKey / rateLimited / providerError) propagate
    /// unchanged so the UI can surface the same messages as the report path.
    static func reply(
        to userMessage: String,
        history: [CoachMessage],
        sessions: [WorkoutSession],
        profile: UserProfile?,
        contextItems: [CoachContextItem],
        client: AIClientProtocol
    ) async throws -> String {
        let prompt = CoachPromptBuilder.chatPrompt(
            sessions: sessions,
            profile: profile,
            contextItems: contextItems,
            history: history,
            userMessage: userMessage
        )
        let raw = try await client.sendRequest(prompt: prompt)
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
