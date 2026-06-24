//
//  DashboardTotalsTests.swift
//  Doggo_V2Tests
//
//  Locks the numbers behind the Dashboard memoization refactor: the memoized
//  totalVolume/totalDuration are exactly the result of these DashboardViewModel
//  functions, so pinning the functions' output proves moving the call from
//  `body` to a recompute-on-change hook preserves what the user sees.
//

import Testing
import Foundation
import SwiftData
@testable import Doggo_V2

@MainActor
struct DashboardTotalsTests {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: WorkoutSession.self, WorkoutSet.self, Exercise.self,
            configurations: config
        )
        return ModelContext(container)
    }

    @Test func totalsAreCorrectDeterministicAndExcludeCardio() throws {
        let ctx = try makeContext()
        let bench = Exercise(name: "Bench", type: "Strength", muscleGroup: "Chest")
        let run = Exercise(name: "Run", type: "Cardio", muscleGroup: "Cardio")
        ctx.insert(bench); ctx.insert(run)

        let s1 = WorkoutSession(name: "A"); s1.duration = 3600; s1.isCompleted = true; ctx.insert(s1)
        let s2 = WorkoutSession(name: "B"); s2.duration = 1800; s2.isCompleted = true; ctx.insert(s2)

        func addSet(_ session: WorkoutSession, _ ex: Exercise, w: Double, reps: Int, unit: String = "lbs") {
            let set = WorkoutSet(weight: w, reps: reps, orderIndex: 0, unit: unit)
            set.exercise = ex
            set.workoutSession = session
            ctx.insert(set)
        }
        addSet(s1, bench, w: 100, reps: 10)   // 1000
        addSet(s1, bench, w: 100, reps: 10)   // 1000  -> strength volume = 2000
        addSet(s2, run, w: 50, reps: 1)       // cardio — must be EXCLUDED from volume

        let vm = DashboardViewModel()
        let sessions = [s1, s2]

        // The exact string the memoized `totalVolume` would hold (cardio excluded).
        let volume = vm.getTotalVolume(from: sessions, preferredUnit: "imperial")
        #expect(volume == "2.0k lbs")
        // Deterministic — recompute-on-change yields the same value as a direct call.
        #expect(vm.getTotalVolume(from: sessions, preferredUnit: "imperial") == volume)

        // The exact string the memoized `totalDuration` would hold: (3600+1800)/3600.
        let duration = vm.getTotalDuration(from: sessions)
        #expect(duration == "1.5 hrs")
        #expect(vm.getTotalDuration(from: sessions) == duration)
    }
}
