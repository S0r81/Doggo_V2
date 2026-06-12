//
//  ProgressionEngine.swift
//  Doggo_V2
//
//  Deterministic progressive-overload rules — no AI required. After a
//  workout, each routine-backed strength exercise is evaluated:
//    · hit every set at (or above) target reps → propose adding weight
//    · miss targets two sessions running     → propose a ~10% deload
//  Proposals are only ever applied through user confirmation.
//

import Foundation
import SwiftData

struct ProgressionProposal: Identifiable {
    enum Kind {
        case increase
        case deload
        case aiTune
    }

    let id = UUID()
    let item: RoutineItem
    let exerciseName: String
    let currentWeight: Double
    let proposedWeight: Double
    let proposedReps: Int?
    let unit: String
    let kind: Kind
    let reason: String
}

enum ProgressionEngine {

    /// Evaluates a finished session and returns proposals for next time.
    /// Also advances each item's success/fail streaks (the streaks record
    /// what happened; proposals are what the user may do about it).
    static func review(session: WorkoutSession) -> [ProgressionProposal] {
        let isMetric = UserDefaults.standard.string(forKey: "unitSystem") == "metric"
        var proposals: [ProgressionProposal] = []

        // Group the session's sets by their routine item
        var grouped: [ObjectIdentifier: (item: RoutineItem, sets: [WorkoutSet])] = [:]
        for set in session.sets {
            guard let item = set.routineItem,
                  let exercise = item.exercise,
                  !exercise.isCardio else { continue }
            let key = ObjectIdentifier(item)
            grouped[key, default: (item, [])].sets.append(set)
        }

        for (_, entry) in grouped {
            let item = entry.item
            guard let exercise = item.exercise else { continue }

            let sets = entry.sets.sorted { $0.orderIndex < $1.orderIndex }
            let templates = item.templateSets.sorted { $0.orderIndex < $1.orderIndex }
            let workingWeight = sets.map(\.weight).max() ?? 0
            let unit = sets.first?.unit ?? (isMetric ? "kg" : "lbs")

            // Only standard strength units participate
            guard workingWeight > 0, unit == "lbs" || unit == "kg" else { continue }

            // Success = every set completed at or above its template's reps
            let allTargetsHit = !sets.isEmpty && sets.enumerated().allSatisfy { index, set in
                guard set.isCompleted else { return false }
                guard !templates.isEmpty else { return set.reps > 0 }
                let target = templates[min(index, templates.count - 1)].targetReps
                return set.reps >= target
            }

            if allTargetsHit {
                item.successStreak += 1
                item.failStreak = 0

                let increment = increment(for: exercise, isMetric: unit == "kg")
                let proposed = roundToPlate(workingWeight + increment, isKg: unit == "kg")
                let repsText = templates.first.map { " × \($0.targetReps)" } ?? ""

                proposals.append(ProgressionProposal(
                    item: item,
                    exerciseName: exercise.name,
                    currentWeight: workingWeight,
                    proposedWeight: proposed,
                    proposedReps: nil,
                    unit: unit,
                    kind: .increase,
                    reason: "Hit every set\(repsText) — time to add weight"
                ))
            } else {
                item.failStreak += 1
                item.successStreak = 0

                if item.failStreak >= 2 {
                    let proposed = roundToPlate(workingWeight * 0.9, isKg: unit == "kg")
                    proposals.append(ProgressionProposal(
                        item: item,
                        exerciseName: exercise.name,
                        currentWeight: workingWeight,
                        proposedWeight: proposed,
                        proposedReps: nil,
                        unit: unit,
                        kind: .deload,
                        reason: "Missed targets \(item.failStreak) sessions in a row — deload to rebuild momentum"
                    ))
                }
            }
        }

        return proposals.sorted { $0.exerciseName < $1.exerciseName }
    }

    /// Writes accepted proposals into the routine templates.
    static func apply(_ proposals: [ProgressionProposal], context: ModelContext) {
        for proposal in proposals {
            for template in proposal.item.templateSets {
                template.targetWeight = proposal.proposedWeight
                if let reps = proposal.proposedReps {
                    template.targetReps = reps
                }
            }
            // A fresh target means a fresh slate
            proposal.item.successStreak = 0
            proposal.item.failStreak = 0
        }
        try? context.save()
    }

    // MARK: - Helpers

    /// Bigger jumps for lower-body lifts, smaller for upper.
    static func increment(for exercise: Exercise, isMetric: Bool) -> Double {
        let lowerBody = exercise.muscleGroup == "Legs"
            || exercise.name.localizedCaseInsensitiveContains("Deadlift")
            || exercise.name.localizedCaseInsensitiveContains("Squat")
        if isMetric { return lowerBody ? 5 : 2.5 }
        return lowerBody ? 10 : 5
    }

    /// Rounds to the smallest loadable jump (2×1.25 lb / 2×0.625 kg plates).
    static func roundToPlate(_ weight: Double, isKg: Bool) -> Double {
        let step = isKg ? 1.25 : 2.5
        return (weight / step).rounded() * step
    }
}
