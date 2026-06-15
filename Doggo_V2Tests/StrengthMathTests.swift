//
//  StrengthMathTests.swift
//  Doggo_V2Tests
//
//  Characterization coverage for the Progress-tab / progression-engine math:
//  Epley e1RM, lbs normalization, and the PR / muscle-balance aggregations over
//  real SwiftData models (built in an in-memory store).
//

import Testing
import Foundation
import SwiftData
@testable import Doggo_V2

struct StrengthMathTests {

    // MARK: - Pure functions

    @Test func epleyOneRepMax() {
        #expect(StrengthMath.estimatedOneRepMax(weight: 100, reps: 1) == 100)        // 1 rep = the weight
        #expect(StrengthMath.estimatedOneRepMax(weight: 225, reps: 5) == 262.5)      // 225 × (1 + 5/30)
        #expect(abs(StrengthMath.estimatedOneRepMax(weight: 100, reps: 10) - 133.333) < 0.01)
        #expect(StrengthMath.estimatedOneRepMax(weight: 0, reps: 5) == 0)            // guard
        #expect(StrengthMath.estimatedOneRepMax(weight: 100, reps: 0) == 0)          // guard
    }

    @Test func inPoundsNormalization() {
        #expect(abs(StrengthMath.inPounds(100, unit: "kg") - 220.462) < 0.01)
        #expect(StrengthMath.inPounds(200, unit: "lbs") == 200)
    }

    // MARK: - Model-backed aggregations

    private func makeStore() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutSession.self, WorkoutSet.self, Exercise.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @discardableResult
    private func addSet(_ ctx: ModelContext, to session: WorkoutSession, exercise: Exercise,
                        weight: Double, reps: Int, unit: String, completed: Bool = true) -> WorkoutSet {
        let set = WorkoutSet(weight: weight, reps: reps, orderIndex: session.sets.count, unit: unit)
        set.isCompleted = completed
        set.exercise = exercise
        set.workoutSession = session
        ctx.insert(set)
        return set
    }

    @Test func personalRecordsPicksHeaviestPerExerciseAndExcludesNoise() throws {
        let ctx = try makeStore()
        let bench = Exercise(name: "Barbell Bench Press", type: "Strength", muscleGroup: "Chest")
        let run = Exercise(name: "Treadmill Run", type: "Cardio", muscleGroup: "Cardio")
        ctx.insert(bench); ctx.insert(run)

        let session = WorkoutSession(name: "Push")
        session.date = Date()
        session.isCompleted = true
        ctx.insert(session)

        addSet(ctx, to: session, exercise: bench, weight: 185, reps: 5, unit: "lbs")
        addSet(ctx, to: session, exercise: bench, weight: 225, reps: 3, unit: "lbs")  // the PR
        addSet(ctx, to: session, exercise: bench, weight: 405, reps: 1, unit: "lbs", completed: false) // incomplete → ignored
        addSet(ctx, to: session, exercise: run, weight: 0, reps: 0, unit: "mi")        // cardio → ignored
        try ctx.save()

        let prs = StrengthMath.personalRecords(from: [session])
        #expect(prs.count == 1)                          // only the strength exercise
        #expect(prs[0].exerciseName == "Barbell Bench Press")
        #expect(prs[0].weight == 225)                    // heaviest *completed* set
        #expect(prs[0].reps == 3)
    }

    @Test func personalRecordsComparesAcrossUnits() throws {
        let ctx = try makeStore()
        let dl = Exercise(name: "Deadlift", type: "Strength", muscleGroup: "Back")
        ctx.insert(dl)
        let session = WorkoutSession(name: "Pull"); session.date = Date(); session.isCompleted = true
        ctx.insert(session)
        addSet(ctx, to: session, exercise: dl, weight: 405, reps: 1, unit: "lbs")  // 405 lb
        addSet(ctx, to: session, exercise: dl, weight: 200, reps: 1, unit: "kg")   // 440.9 lb → wins
        try ctx.save()

        let prs = StrengthMath.personalRecords(from: [session])
        #expect(prs.count == 1)
        #expect(prs[0].unit == "kg")
        #expect(prs[0].weight == 200)
    }

    @Test func setsPerMuscleGroupCountsWithinWindowOnly() throws {
        let ctx = try makeStore()
        let bench = Exercise(name: "Bench", type: "Strength", muscleGroup: "Chest")
        let squat = Exercise(name: "Squat", type: "Strength", muscleGroup: "Legs")
        let run = Exercise(name: "Run", type: "Cardio", muscleGroup: "Cardio")
        [bench, squat, run].forEach { ctx.insert($0) }

        let recent = WorkoutSession(name: "Recent"); recent.date = Date(); recent.isCompleted = true
        let old = WorkoutSession(name: "Old")
        old.date = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        old.isCompleted = true
        ctx.insert(recent); ctx.insert(old)

        addSet(ctx, to: recent, exercise: bench, weight: 135, reps: 8, unit: "lbs")
        addSet(ctx, to: recent, exercise: bench, weight: 135, reps: 8, unit: "lbs")
        addSet(ctx, to: recent, exercise: squat, weight: 225, reps: 5, unit: "lbs")
        addSet(ctx, to: recent, exercise: run, weight: 0, reps: 0, unit: "mi")        // cardio excluded
        addSet(ctx, to: old, exercise: bench, weight: 135, reps: 8, unit: "lbs")      // out of window
        try ctx.save()

        let since = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let groups = StrengthMath.setsPerMuscleGroup(from: [recent, old], since: since)
        let dict = Dictionary(uniqueKeysWithValues: groups.map { ($0.group, $0.sets) })
        #expect(dict["Chest"] == 2)        // old bench set excluded by window
        #expect(dict["Legs"] == 1)
        #expect(dict["Cardio"] == nil)     // cardio never counts
        #expect(groups.first?.group == "Chest")   // sorted by volume desc
    }
}
