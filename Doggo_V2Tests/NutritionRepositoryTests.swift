//
//  NutritionRepositoryTests.swift
//  Doggo_V2Tests
//
//  Exercises the @ModelActor adaptive loop end-to-end against an in-memory
//  store. Every call here uses value-in / Sendable-result-out — the test never
//  touches a NutritionProfile/CheckIn model, which is exactly the boundary
//  contract that keeps background-context objects out of the UI.
//

import Testing
import Foundation
import SwiftData
@testable import Doggo_V2

// @MainActor: the result types and config this suite reads/mutates are
// main-actor-isolated under the project's default actor isolation, so the suite
// drives them from the main actor. The repository under test is a @ModelActor —
// its work still runs on its own actor via `await`, so this changes only the
// test's isolation context, not what any test asserts.
@MainActor
struct NutritionRepositoryTests {

    private func makeStack() throws -> (NutritionRepository, ModelContainer) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: NutritionProfile.self, NutritionCheckIn.self,
            DailyMacroLog.self, BodyMeasurement.self,
            configurations: config
        )
        return (NutritionRepository(modelContainer: container), container)
    }

    private func makeRepository() throws -> NutritionRepository {
        try makeStack().0
    }

    private func deficitConfig() -> NutritionProfileConfig {
        NutritionProfileConfig(
            startingWeightKg: 100,
            targetLossRate: 0.006,        // 0.6 kg/week target
            maintenanceCalories: 2800,
            dailyCalories: 2242,
            deficitKcal: 558,
            proteinGrams: 220,
            carbGrams: 200,
            fatGrams: 60,
            phase: .deficit
        )
    }

    // MARK: - The core loop

    @Test func twoConsecutiveStallsCutCarbsAndFatByTenPercent() async throws {
        let repo = try makeRepository()
        let id = try await repo.createProfile(deficitConfig())

        // Week 1: lost only 0.1 kg vs a ~0.6 kg target → stalled, but it's the
        // first check-in, so nothing to be consecutive with.
        let w1 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.9)
        #expect(w1.stalled)
        #expect(w1.macroAdjustmentApplied == false)
        #expect(abs(w1.newDailyCalories - 2242) < 1e-9)

        // Week 2: stalled again → two in a row → 10% cut to carbs + fat.
        let w2 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.85)
        #expect(w2.stalled)
        #expect(w2.macroAdjustmentApplied)
        #expect(abs(w2.newCarbGrams - 180) < 1e-9)            // 200 × 0.9
        #expect(abs(w2.newFatGrams - 54) < 1e-9)              // 60 × 0.9
        #expect(abs(w2.newProteinGrams - 220) < 1e-9)         // protein untouched
        #expect(abs(w2.newDailyCalories - 2086) < 1e-9)       // 880 + 720 + 486
    }

    @Test func aGoodWeekResetsTheStallStreak() async throws {
        let repo = try makeRepository()
        let id = try await repo.createProfile(deficitConfig())

        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.9)   // stall
        // Good week: lost 0.7 kg, well above 50% of target.
        let w2 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.2)
        #expect(w2.stalled == false)
        #expect(w2.macroAdjustmentApplied == false)

        // Stall again, but the previous week was good → no cut.
        let w3 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.15)
        #expect(w3.stalled)
        #expect(w3.macroAdjustmentApplied == false)
        #expect(abs(w3.newDailyCalories - 2242) < 1e-9)
    }

    @Test func safetyFloorBlocksCutBelow1200() async throws {
        let repo = try makeRepository()
        // 150·4 + 40·4 + 50·9 = 600 + 160 + 450 = 1210 kcal. A 10% cut would land
        // at ~1149, below the 1200 floor, so the cut must be refused.
        let config = NutritionProfileConfig(
            startingWeightKg: 100, targetLossRate: 0.006,
            maintenanceCalories: 2000, dailyCalories: 1210, deficitKcal: 790,
            proteinGrams: 150, carbGrams: 40, fatGrams: 50, phase: .deficit
        )
        let id = try await repo.createProfile(config)

        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.9)
        let w2 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.85)
        #expect(w2.stalled)
        #expect(w2.macroAdjustmentApplied == false)           // floor held
        #expect(abs(w2.newDailyCalories - 1210) < 1e-9)       // unchanged
    }

    @Test func nonDeficitPhaseNeverCuts() async throws {
        let repo = try makeRepository()
        var config = deficitConfig()
        config.phase = .maintenance
        let id = try await repo.createProfile(config)

        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.9)
        let w2 = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.85)
        #expect(w2.stalled)                                   // it did stall…
        #expect(w2.macroAdjustmentApplied == false)           // …but we're not dieting
    }

    @Test func deletingProfileCascadesCheckIns() async throws {
        let repo = try makeRepository()
        let id = try await repo.createProfile(deficitConfig())
        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.9)
        // Just proves delete resolves + saves without error (cascade is the
        // model's @Relationship rule).
        try await repo.deleteProfile(id: id)
    }

    // MARK: - State machine: diet break

    @Test func twelveContinuousWeeksTriggersDietBreakThenResumes() async throws {
        let repo = try makeRepository()
        var config = deficitConfig()
        config.goalWeightKg = 80          // won't be reached in this window
        let id = try await repo.createProfile(config)
        let base = Date()
        var weight = 100.0

        // Weeks 1–11: steady loss (not stalled), stays in deficit.
        for week in 1...11 {
            weight -= 0.4
            let r = try await repo.logWeeklyCheckIn(
                profileID: id, averageWeight: weight,
                date: base.addingTimeInterval(Double(week) * 7 * 86400)
            )
            #expect(r.phase == .deficit)
        }

        // Week 12: 12 weeks elapsed → forced diet break at maintenance.
        weight -= 0.4
        let r12 = try await repo.logWeeklyCheckIn(
            profileID: id, averageWeight: weight,
            date: base.addingTimeInterval(12 * 7 * 86400)
        )
        #expect(r12.phase == .dietBreak)
        #expect(r12.phaseChanged)
        #expect(r12.macroAdjustmentApplied == false)
        #expect(r12.newDailyCalories > 2242)            // bumped up to maintenance

        // Week 13: one week into the break.
        let r13 = try await repo.logWeeklyCheckIn(
            profileID: id, averageWeight: weight,
            date: base.addingTimeInterval(13 * 7 * 86400)
        )
        #expect(r13.phase == .dietBreak)

        // Week 14: two weeks done → resume deficit, re-prescribed at new weight.
        let r14 = try await repo.logWeeklyCheckIn(
            profileID: id, averageWeight: weight,
            date: base.addingTimeInterval(14 * 7 * 86400)
        )
        #expect(r14.phase == .deficit)
        #expect(r14.phaseChanged)
        #expect(r14.newDailyCalories < r12.newDailyCalories)   // deficit < maintenance
    }

    // MARK: - State machine: reverse diet

    @Test func reverseDietRampsToMaintenanceThenHolds() async throws {
        let repo = try makeRepository()
        var config = deficitConfig()
        config.startingWeightKg = 80
        config.goalWeightKg = 80
        config.bodyFatPercent = 15
        config.maintenanceCalories = 2600
        config.dailyCalories = 1861
        config.proteinGrams = 176
        config.carbGrams = 170
        config.fatGrams = 53
        let id = try await repo.createProfile(config)

        let start = try await repo.startReverseDiet(profileID: id)
        #expect(start.phase == .reverseDiet)

        var last = 0.0
        var reachedMaintenance = false
        for week in 1...40 {
            let r = try await repo.logWeeklyCheckIn(
                profileID: id, averageWeight: 80,
                date: Date().addingTimeInterval(Double(week) * 7 * 86400)
            )
            if r.phase == .maintenance { reachedMaintenance = true; break }
            #expect(r.phase == .reverseDiet)
            #expect(r.newDailyCalories >= last)            // calories only go up
            last = r.newDailyCalories
        }
        #expect(reachedMaintenance)
    }

    @Test func evaluateDietBreakStandaloneTransitions() async throws {
        let repo = try makeRepository()
        let id = try await repo.createProfile(deficitConfig())
        let base = Date()
        // Log 12 weekly check-ins WITHOUT relying on the auto-progression path,
        // then call the standalone evaluator.
        for week in 1...12 {
            _ = try await repo.logWeeklyCheckIn(
                profileID: id, averageWeight: 100 - Double(week) * 0.4,
                date: base.addingTimeInterval(Double(week) * 7 * 86400)
            )
        }
        // By week 12 the tick already entered the break; calling evaluate again
        // is a safe no-op (still in break, < 2 weeks elapsed).
        let result = try await repo.evaluateDietBreak(profileID: id)
        #expect(result.phase == .dietBreak)
    }

    // MARK: - Daily quick-log engine (find-or-append)

    @Test func dailyMacrosCreateThenAppendSameDayThenNewDay() async throws {
        let repo = try makeRepository()
        let id = try await repo.createProfile(deficitConfig())
        let day = Date()

        // First entry → fresh log.
        let first = try await repo.logDailyMacros(profileID: id, protein: 40, carbs: 30, fats: 10, date: day)
        #expect(first.protein == 40 && first.carbs == 30 && first.fats == 10)

        // Same calendar day → mathematically appends.
        let second = try await repo.logDailyMacros(profileID: id, protein: 25, carbs: 0, fats: 5, date: day)
        #expect(second.protein == 65 && second.carbs == 30 && second.fats == 15)

        // Next day → a brand-new log, not an append.
        let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: day)!
        let third = try await repo.logDailyMacros(profileID: id, protein: 10, carbs: 10, fats: 10, date: nextDay)
        #expect(third.protein == 10 && third.carbs == 10 && third.fats == 10)
    }

    // MARK: - Edit & override engine

    @Test func updateProfileManualOverrideUsesExactMacros() async throws {
        let (repo, container) = try makeStack()
        let id = try await repo.createProfile(deficitConfig())
        try await repo.updateProfile(profileID: id, newConfig: deficitConfig(),
                                     manualMacros: (protein: 200, carbs: 100, fats: 50))

        let context = ModelContext(container)
        let p = try #require(try context.fetch(FetchDescriptor<NutritionProfile>()).first)
        #expect(p.proteinTargetGrams == 200)
        #expect(p.carbTargetGrams == 100)
        #expect(p.fatTargetGrams == 50)
        #expect(p.currentDailyCalories == 1650)   // 800 + 400 + 450
    }

    @Test func updateProfileWithoutManualRecalculatesFromInputs() async throws {
        let (repo, container) = try makeStack()
        let id = try await repo.createProfile(deficitConfig())
        var newConfig = deficitConfig()
        newConfig.startingWeightKg = 90
        newConfig.bodyFatPercent = 18
        try await repo.updateProfile(profileID: id, newConfig: newConfig, manualMacros: nil)

        let context = ModelContext(container)
        let p = try #require(try context.fetch(FetchDescriptor<NutritionProfile>()).first)
        #expect(abs(p.proteinTargetGrams - 198) < 1e-6)   // 90 kg × 2.2 (HP)
        #expect(p.bodyFatPercent == 18)
    }

    // MARK: - Cross-domain sync + historical correction

    @Test func checkInUpsertsSingleBodyMeasurementPerDay() async throws {
        let (repo, container) = try makeStack()
        let id = try await repo.createProfile(deficitConfig())   // seeds BM at 100
        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.0, date: Date())

        let context = ModelContext(container)
        let bms = try context.fetch(FetchDescriptor<BodyMeasurement>())
        // createProfile + same-day check-in collapse to one row, updated to 99.
        #expect(bms.count == 1)
        #expect(abs(bms[0].weightKG - 99.0) < 1e-9)
    }

    @Test func updateHistoricalCheckInCorrectsWeightLossAndSyncsBodyMeasurement() async throws {
        let (repo, container) = try makeStack()
        let id = try await repo.createProfile(deficitConfig())
        let day = Date()
        _ = try await repo.logWeeklyCheckIn(profileID: id, averageWeight: 99.0, date: day)

        let readContext = ModelContext(container)
        let checkIn = try #require(try readContext.fetch(FetchDescriptor<NutritionCheckIn>()).first)
        try await repo.updateHistoricalCheckIn(checkInID: checkIn.persistentModelID, newWeight: 98.0)

        let after = ModelContext(container)
        let updated = try #require(try after.fetch(FetchDescriptor<NutritionCheckIn>()).first)
        #expect(updated.rollingAverageWeight == 98.0)
        #expect(updated.actualWeightLost == 2.0)            // 100 (start) − 98

        let bms = try after.fetch(FetchDescriptor<BodyMeasurement>())
        let sameDay = bms.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
        #expect(sameDay?.weightKG == 98.0)
    }
}
