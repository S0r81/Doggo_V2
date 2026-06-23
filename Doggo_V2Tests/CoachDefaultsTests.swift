//
//  CoachDefaultsTests.swift
//  Doggo_V2Tests
//
//  Stage 5 regression guard: an existing user with no "What Coach knows" items
//  and no chat history must still get the original Report behavior — a non-empty,
//  context-free prompt (no empty-prompt, no crash) — and Report stays the default.
//

import Testing
import Foundation
@testable import Doggo_V2

struct CoachDefaultsTests {

    @Test func reportPromptWithNoContextIsNonEmptyAndUnchanged() {
        let prompt = GeminiPromptBuilder.buildAnalysisPrompt(
            sessions: [], profile: nil, contextItems: []
        )
        #expect(!prompt.isEmpty)
        #expect(prompt.contains("YOUR MISSION"))
        #expect(prompt.contains("QUANTITATIVE DATA (Last 30 Days)"))
        #expect(prompt.contains("User Profile: Unknown"))               // nil-profile grounding
        #expect(!prompt.contains("WHAT YOU KNOW ABOUT THIS USER"))      // no context → no block
    }

    @Test func chatPromptWithNoHistoryOrContextIsNonEmpty() {
        let prompt = CoachPromptBuilder.chatPrompt(
            sessions: [], profile: nil, contextItems: [], history: [], userMessage: "hi"
        )
        #expect(!prompt.isEmpty)
        #expect(prompt.contains("hi"))
        #expect(prompt.contains("this is the first message"))
        #expect(!prompt.contains("WHAT YOU KNOW ABOUT THIS USER"))
    }

    @Test func reportModeIsTheDefault() {
        // Absent persisted value resolves to .report (the @AppStorage default),
        // and Report is first in the toggle.
        #expect(CoachMode(rawValue: "report") == .report)
        #expect(CoachMode.allCases.first == .report)
    }
}
