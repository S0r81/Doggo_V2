//
//  StrengthMath.swift
//  Doggo_V2
//
//  Shared strength calculations for the Progress tab, exercise details, and
//  the progression engine.
//

import Foundation

enum StrengthMath {

    /// Epley estimated one-rep max. Weight in the caller's unit.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30.0)
    }

    /// Weight normalized to pounds for cross-unit comparisons.
    static func inPounds(_ weight: Double, unit: String) -> Double {
        unit == "kg" ? weight * 2.20462 : weight
    }

    /// The all-time best (heaviest completed set) for an exercise.
    struct PersonalRecord {
        let exerciseName: String
        let weight: Double
        let reps: Int
        let unit: String
        let date: Date
        let exercise: Exercise?

        var estimatedOneRepMax: Double {
            StrengthMath.estimatedOneRepMax(weight: weight, reps: reps)
        }
    }

    /// Current PR per strength exercise from completed sessions, heaviest
    /// (lbs-normalized) first.
    static func personalRecords(from sessions: [WorkoutSession]) -> [PersonalRecord] {
        var best: [String: PersonalRecord] = [:]

        for session in sessions {
            for set in session.sets where set.isCompleted && set.weight > 0 {
                guard let exercise = set.exercise, !exercise.isCardio else { continue }

                let candidate = PersonalRecord(
                    exerciseName: exercise.name,
                    weight: set.weight,
                    reps: set.reps,
                    unit: set.unit,
                    date: session.date,
                    exercise: exercise
                )

                let key = exercise.name.lowercased()
                if let current = best[key] {
                    if inPounds(candidate.weight, unit: candidate.unit) > inPounds(current.weight, unit: current.unit) {
                        best[key] = candidate
                    }
                } else {
                    best[key] = candidate
                }
            }
        }

        return best.values.sorted {
            inPounds($0.weight, unit: $0.unit) > inPounds($1.weight, unit: $1.unit)
        }
    }

    /// Completed sets per muscle group within the window, for balance checks.
    static func setsPerMuscleGroup(from sessions: [WorkoutSession], since: Date) -> [(group: String, sets: Int)] {
        var counts: [String: Int] = [:]
        for session in sessions where session.date >= since {
            for set in session.sets where set.isCompleted {
                guard let exercise = set.exercise, !exercise.isCardio else { continue }
                counts[exercise.muscleGroup, default: 0] += 1
            }
        }
        return counts.map { ($0.key, $0.value) }.sorted { $0.sets > $1.sets }
    }
}
