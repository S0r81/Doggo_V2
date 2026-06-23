//
//  CoachChatEngineTests.swift
//  Doggo_V2Tests
//
//  Stage 2 gate for Coach chat: every chat turn must inject the standing
//  "What Coach knows" context and the shared data grounding, must respect the
//  history window, and must surface provider errors with the same user-facing
//  message the report path already shows — all through the existing client
//  protocol (no second networking path).
//

import Testing
import Foundation
@testable import Doggo_V2

/// Records the prompt it is handed; optionally throws a canned error instead.
private final class MockAIClient: AIClientProtocol, @unchecked Sendable {
    var lastPrompt: String?
    var stubbedReply = "Sure — here's a plan."
    var stubbedError: Error?

    func sendRequest(prompt: String) async throws -> String {
        lastPrompt = prompt
        if let stubbedError { throw stubbedError }
        return stubbedReply
    }
}

@MainActor
struct CoachChatEngineTests {

    private let thread = UUID()

    @Test func promptInjectsStandingContextAndGrounding() async throws {
        let client = MockAIClient()
        let context = [
            CoachContextItem(category: .injuries, text: "left knee — no deep squats"),
            CoachContextItem(category: .equipment, text: "home gym, no barbell")
        ]

        _ = try await CoachChatEngine.reply(
            to: "Build me a leg day",
            history: [],
            sessions: [],
            profile: nil,
            contextItems: context,
            client: client
        )

        let prompt = try #require(client.lastPrompt)
        // Standing context is present...
        #expect(prompt.contains("left knee — no deep squats"))
        #expect(prompt.contains("home gym, no barbell"))
        #expect(prompt.contains("WHAT YOU KNOW ABOUT THIS USER"))
        // ...alongside the shared data grounding and the new user message.
        #expect(prompt.contains("QUANTITATIVE DATA (Last 30 Days)"))
        #expect(prompt.contains("Build me a leg day"))
    }

    @Test func respectsHistoryWindow() async throws {
        let client = MockAIClient()
        // 20 prior turns; only the last `historyWindow` should be replayed.
        let history = (0..<20).map { i in
            CoachMessage(role: i.isMultiple(of: 2) ? .user : .assistant,
                         text: "TURN_\(i)",
                         threadID: thread,
                         timestamp: Date(timeIntervalSince1970: Double(i)))
        }

        _ = try await CoachChatEngine.reply(
            to: "next",
            history: history,
            sessions: [],
            profile: nil,
            contextItems: [],
            client: client
        )

        let prompt = try #require(client.lastPrompt)
        // Oldest turns are truncated, newest are kept.
        #expect(!prompt.contains("TURN_0"))
        #expect(!prompt.contains("TURN_7"))   // outside the last 12
        #expect(prompt.contains("TURN_8"))    // first kept turn (20 - 12)
        #expect(prompt.contains("TURN_19"))   // most recent
    }

    @Test func emptyContextAddsNoKnowledgeBlock() async throws {
        let client = MockAIClient()
        _ = try await CoachChatEngine.reply(
            to: "hi", history: [], sessions: [], profile: nil,
            contextItems: [], client: client
        )
        let prompt = try #require(client.lastPrompt)
        #expect(!prompt.contains("WHAT YOU KNOW ABOUT THIS USER"))
    }

    @Test func rateLimitErrorSurfacesSameMessageAsReport() async throws {
        let client = MockAIClient()
        client.stubbedError = APIError.rateLimited(detail: "slow down")

        await #expect(throws: APIError.self) {
            _ = try await CoachChatEngine.reply(
                to: "hi", history: [], sessions: [], profile: nil,
                contextItems: [], client: client
            )
        }

        // The user-facing string is exactly what the report path would show.
        do {
            _ = try await CoachChatEngine.reply(
                to: "hi", history: [], sessions: [], profile: nil,
                contextItems: [], client: client
            )
            Issue.record("Expected the rate-limit error to propagate")
        } catch {
            #expect(error.localizedDescription == APIError.rateLimited(detail: "slow down").errorDescription)
        }
    }
}
