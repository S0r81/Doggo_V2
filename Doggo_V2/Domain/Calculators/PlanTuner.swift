//
//  PlanTuner.swift
//  Doggo_V2
//
//  The AI layer of the progression system: sends the current plan + recent
//  results to the configured provider and turns its STRICT-JSON reply into
//  ProgressionProposals — reviewed and applied through the same sheet as the
//  deterministic rules, never silently.
//

import Foundation
import SwiftData

@MainActor
enum PlanTuner {

    enum TuneError: LocalizedError {
        case noTargets
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noTargets: return "No strength exercises with routine templates found to tune."
            case .badResponse: return "The AI response couldn't be read. Try again."
            }
        }
    }

    private struct Response: Decodable {
        struct Adjustment: Decodable {
            let exercise: String
            let weight: Double
            let reps: Int?
            let reason: String
        }
        let adjustments: [Adjustment]
    }

    /// Builds proposals for every adjustment the AI suggests that maps to a
    /// real routine item.
    static func proposals(
        routines: [Routine],
        sessions: [WorkoutSession],
        client: AIClientProtocol
    ) async throws -> [ProgressionProposal] {
        let isMetric = UserDefaults.standard.string(forKey: "unitSystem") == "metric"
        let unit = isMetric ? "kg" : "lbs"

        // Strength items, keyed by lowercased exercise name (first match wins)
        var itemsByExercise: [String: RoutineItem] = [:]
        var planLines: [String] = []

        for routine in routines {
            for item in routine.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                guard let exercise = item.exercise, !exercise.isCardio else { continue }
                let key = exercise.name.lowercased()
                if itemsByExercise[key] == nil { itemsByExercise[key] = item }

                let summary = repSummary(for: item)
                planLines.append("- \(exercise.name) [\(exercise.muscleGroup)] in \"\(routine.name)\": \(summary)")
            }
        }

        guard !itemsByExercise.isEmpty else { throw TuneError.noTargets }

        // Last 4 weeks of best results per exercise
        let fourWeeksAgo = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let recent = sessions.filter { $0.date >= fourWeeksAgo }
        var resultLines: [String] = []
        for record in StrengthMath.personalRecords(from: recent).prefix(20) {
            resultLines.append("- \(record.exerciseName): best \(Int(record.weight)) \(record.unit) × \(record.reps) on \(record.date.formatted(date: .numeric, time: .omitted))")
        }

        let prompt = """
        You are a strength coach reviewing a lifter's training plan. Propose updated target working weights for next week.

        CURRENT PLAN:
        \(planLines.joined(separator: "\n"))

        BEST RESULTS, LAST 4 WEEKS:
        \(resultLines.isEmpty ? "(no logged results yet — propose conservative starting weights only for exercises whose plan already shows an @ weight, otherwise omit them)" : resultLines.joined(separator: "\n"))

        RULES:
        - Weights are in \(unit). Round to the nearest \(isMetric ? "1.25" : "2.5").
        - Be conservative: typical jumps are \(isMetric ? "2.5 kg upper / 5 kg lower" : "5 lbs upper / 10 lbs lower") body.
        - Only include exercises that appear in CURRENT PLAN, max 10 adjustments.
        - Each reason must be one short sentence.

        Respond with ONLY this JSON, no other text:
        {"adjustments":[{"exercise":"Bench Press (Barbell)","weight":190,"reps":5,"reason":"..."}]}
        """

        let raw = try await client.sendRequest(prompt: prompt)

        // Extract the first JSON object from the reply (provider-agnostic)
        guard let start = raw.firstIndex(of: "{"),
              let end = raw.lastIndex(of: "}"),
              let data = String(raw[start...end]).data(using: .utf8),
              let response = try? JSONDecoder().decode(Response.self, from: data) else {
            throw TuneError.badResponse
        }

        var proposals: [ProgressionProposal] = []
        for adjustment in response.adjustments {
            guard let item = itemsByExercise[adjustment.exercise.lowercased()],
                  adjustment.weight > 0 else { continue }

            let current = item.templateSets.compactMap(\.targetWeight).max() ?? 0
            // Skip no-ops
            guard abs(adjustment.weight - current) > 0.01 else { continue }

            proposals.append(ProgressionProposal(
                item: item,
                exerciseName: item.exercise?.name ?? adjustment.exercise,
                currentWeight: current,
                proposedWeight: ProgressionEngine.roundToPlate(adjustment.weight, isKg: isMetric),
                proposedReps: adjustment.reps,
                unit: unit,
                kind: .aiTune,
                reason: adjustment.reason
            ))
        }

        return proposals
    }
}
