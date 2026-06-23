//
//  CoachPromptBuilder.swift
//  Doggo_V2
//
//  The single source of truth for what the AI Coach "knows" on every request.
//  BOTH the report (GeminiPromptBuilder.buildAnalysisPrompt) and the chat engine
//  build their grounding here, so the data + standing-context injection can never
//  drift between the two modes.
//
//  Pure and deterministic (no SwiftData mutation, no UI) — testable directly.
//

import Foundation

nonisolated enum CoachPromptBuilder {

    /// How many trailing chat turns are replayed to the model. Older turns are
    /// truncated (not summarized) to keep the prompt inside the token budget —
    /// a deliberate, predictable cap. Summarizing older history is a possible
    /// future upgrade but would cost an extra round-trip per turn.
    static let historyWindow = 12

    static let chatPersona = """
    You are Doggo's AI training partner — a sharp strength, conditioning, and \
    nutrition coach. You already have this user's real training data and standing \
    context below, so reason from it directly instead of asking them to repeat it. \
    Be specific, practical, and concise; use Markdown. If something they ask \
    conflicts with a known injury or limitation, say so and adapt.
    """

    // MARK: - Shared grounding

    /// Quantitative training grounding shared by the report and chat: profile,
    /// 30-day stats, and the recent activity log. Identical wording to the
    /// long-standing report grounding so behavior is preserved.
    static func trainingDataBlock(sessions: [WorkoutSession], profile: UserProfile?) -> String {
        let stats = calculateStats(from: sessions)
        let recentHistory = sessions.sorted { $0.date > $1.date }.prefix(10)
        var historyString = ""

        for session in recentHistory {
            let date = session.date.formatted(date: .numeric, time: .omitted)
            historyString += "- \(date): \(session.name) (\(Int(session.duration/60)) min)\n"

            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            let heavySets = sortedSets.filter { $0.weight > 0 }.prefix(8)
            for set in heavySets {
                if let name = set.exercise?.name {
                    historyString += "  * \(name): \(Int(set.weight)) \(set.unit) x \(set.reps)\n"
                }
            }
        }

        var userContext = "User Profile: Unknown"
        if let p = profile {
            userContext = """
            User Profile:
            - Goal: \(p.fitnessGoal)
            - Experience: \(p.experienceLevel)
            """
        }

        return """
        \(userContext)

        QUANTITATIVE DATA (Last 30 Days):
        - Workout Consistency: \(stats.workoutsPerWeek) sessions/week
        - Avg Session Duration: \(stats.avgDuration)
        - Muscle Focus Split: \(stats.muscleSplit)
        - Total Volume: \(stats.totalVolume) lbs

        RECENT ACTIVITY LOG (Newest first):
        \(historyString)
        """
    }

    /// The user's standing "What Coach knows" context, or "" if none.
    static func knowledgeBlock(contextItems: [CoachContextItem]) -> String {
        CoachContextAssembler.contextBlock(from: contextItems)
    }

    // MARK: - Chat prompt

    /// Full chat prompt: persona + shared grounding + standing context + the
    /// last `historyWindow` turns + the new user message.
    static func chatPrompt(
        sessions: [WorkoutSession],
        profile: UserProfile?,
        contextItems: [CoachContextItem],
        history: [CoachMessage],
        userMessage: String
    ) -> String {
        let grounding = trainingDataBlock(sessions: sessions, profile: profile)
        let knowledge = knowledgeBlock(contextItems: contextItems)
        let knowledgeSection = knowledge.isEmpty ? "" : "\n\(knowledge)\n"

        let recent = history.suffix(historyWindow)
        let transcript = recent
            .map { "\($0.role == .assistant ? "Coach" : "User"): \($0.text)" }
            .joined(separator: "\n")

        return """
        \(chatPersona)

        \(grounding)
        \(knowledgeSection)
        CONVERSATION SO FAR:
        \(transcript.isEmpty ? "(this is the first message)" : transcript)

        User: \(userMessage)
        Coach:
        """
    }

    // MARK: - Stats (relocated from GeminiPromptBuilder so grounding lives in one place)

    private static func calculateStats(from sessions: [WorkoutSession]) -> AnalysisStats {
        let oneMonthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentSessions = sessions.filter { $0.date > oneMonthAgo }

        let freq = String(format: "%.1f", Double(recentSessions.count) / 4.0)

        let totalSeconds = recentSessions.reduce(0) { $0 + $1.duration }
        let avgSeconds = recentSessions.isEmpty ? 0 : totalSeconds / Double(recentSessions.count)
        let avgDur = "\(Int(avgSeconds / 60)) min"

        var vol: Double = 0
        var muscleCounts: [String: Int] = [:]

        for session in recentSessions {
            for set in session.sets {
                let w = set.unit == "kg" ? set.weight * 2.2 : set.weight
                vol += (w * Double(set.reps))
                if let muscle = set.exercise?.muscleGroup {
                    muscleCounts[muscle, default: 0] += 1
                }
            }
        }

        let sortedMuscles = muscleCounts.sorted { $0.value > $1.value }.prefix(3)
        let splitString = sortedMuscles.map { "\($0.key) (\($0.value) sets)" }.joined(separator: ", ")

        return AnalysisStats(
            workoutsPerWeek: freq,
            avgDuration: avgDur,
            muscleSplit: splitString.isEmpty ? "General Full Body" : splitString,
            totalVolume: "\(Int(vol))"
        )
    }

    private struct AnalysisStats {
        let workoutsPerWeek: String
        let avgDuration: String
        let muscleSplit: String
        let totalVolume: String
    }
}
