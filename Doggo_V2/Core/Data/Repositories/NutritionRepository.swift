//
//  NutritionRepository.swift
//  Doggo_V2
//
//  Background-safe persistence + the adaptive diet state machine. A @ModelActor
//  that owns its context; every entry point takes value types or a Sendable
//  PersistentIdentifier and returns value types only. No SwiftData model ever
//  crosses back to the caller, so background-context objects can never enter a
//  main-context relationship.
//
//  Cross-domain sync: logging a weight also upserts a BodyMeasurement (the
//  Progress tab's record) on THIS actor's context. BodyMeasurement holds no
//  relationship to the nutrition models, so there is no schema cycle and no
//  Sendable boundary is crossed — the model is built and saved here.
//

import Foundation
import SwiftData

struct NutritionProfileConfig: Sendable {
    var startingWeightKg: Double
    var goalWeightKg: Double = 0
    var targetLossRate: Double
    var bodyFatPercent: Double = 20
    var sex: BiologicalSex = .male
    var ageYears: Int = 30
    var activity: ActivityLevel = .moderate
    var proteinPref: ProteinPreference = .high
    var resistanceTraining: Bool = true
    var maintenanceCalories: Double
    var dailyCalories: Double
    var deficitKcal: Double
    var proteinGrams: Double
    var carbGrams: Double
    var fatGrams: Double
    var phase: NutritionPhase = .deficit
}

struct WeeklyCheckInResult: Sendable {
    let actualWeightLost: Double
    let targetWeightLost: Double
    let stalled: Bool
    let macroAdjustmentApplied: Bool
    let reachedGoal: Bool
    let phase: NutritionPhase
    let phaseChanged: Bool
    let newDailyCalories: Double
    let newProteinGrams: Double
    let newCarbGrams: Double
    let newFatGrams: Double
}

struct PhaseTransitionResult: Sendable {
    let phase: NutritionPhase
    let changed: Bool
    let newDailyCalories: Double
}

/// Sendable carrier for a day's running macro totals.
struct DailyMacroTotals: Sendable {
    let protein: Int
    let carbs: Int
    let fats: Int
}

protocol NutritionRepositoryProtocol {
    @discardableResult
    func createProfile(_ config: NutritionProfileConfig) async throws -> PersistentIdentifier
    @discardableResult
    func logWeeklyCheckIn(profileID: PersistentIdentifier, averageWeight: Double, date: Date) async throws -> WeeklyCheckInResult
    @discardableResult
    func evaluateDietBreak(profileID: PersistentIdentifier) async throws -> PhaseTransitionResult
    @discardableResult
    func startReverseDiet(profileID: PersistentIdentifier) async throws -> PhaseTransitionResult
    func updateProfile(profileID: PersistentIdentifier, newConfig: NutritionProfileConfig, manualMacros: (protein: Int, carbs: Int, fats: Int)?) async throws
    @discardableResult
    func logDailyMacros(profileID: PersistentIdentifier, protein: Int, carbs: Int, fats: Int, date: Date) async throws -> DailyMacroTotals
    func updateHistoricalCheckIn(checkInID: PersistentIdentifier, newWeight: Double) async throws
    func deleteProfile(id: PersistentIdentifier) async throws
}

enum NutritionRepositoryError: LocalizedError {
    case profileNotFound
    case checkInNotFound
    var errorDescription: String? {
        switch self {
        case .profileNotFound: return "That nutrition profile no longer exists."
        case .checkInNotFound: return "That check-in no longer exists."
        }
    }
}

@ModelActor
actor NutritionRepository: NutritionRepositoryProtocol {

    private let safetyFloorCalories: Double = 1200
    private let dietBreakTriggerWeeks = 12
    private let dietBreakLengthWeeks = 2

    // MARK: - Create

    @discardableResult
    func createProfile(_ config: NutritionProfileConfig) async throws -> PersistentIdentifier {
        let profile = NutritionProfile(
            startingWeightKg: config.startingWeightKg,
            goalWeightKg: config.goalWeightKg,
            targetLossRate: config.targetLossRate,
            bodyFatPercent: config.bodyFatPercent,
            sex: config.sex,
            ageYears: config.ageYears,
            activity: config.activity,
            proteinPreference: config.proteinPref,
            resistanceTraining: config.resistanceTraining,
            maintenanceCalories: config.maintenanceCalories,
            currentDailyCalories: config.dailyCalories,
            dailyDeficitKcal: config.deficitKcal,
            proteinTargetGrams: config.proteinGrams,
            carbTargetGrams: config.carbGrams,
            fatTargetGrams: config.fatGrams,
            phase: config.phase
        )
        modelContext.insert(profile)
        // Cross-domain: seed the Progress tab's weight history with day zero.
        upsertBodyMeasurement(weightKg: config.startingWeightKg, date: Date(), note: "Diet start")
        try modelContext.save()
        return profile.persistentModelID
    }

    // MARK: - Weekly check-in (the tick that drives everything)

    @discardableResult
    func logWeeklyCheckIn(profileID: PersistentIdentifier, averageWeight: Double, date: Date = Date()) async throws -> WeeklyCheckInResult {
        guard let profile = self[profileID, as: NutritionProfile.self] else {
            throw NutritionRepositoryError.profileNotFound
        }

        let priorCheckIns = profile.checkIns.sorted { $0.date > $1.date }
        let previousCheckIn = priorCheckIns.first
        let previousWeight = previousCheckIn?.rollingAverageWeight ?? profile.startingWeightKg

        let actualWeightLost = previousWeight - averageWeight
        let targetWeightLost = previousWeight * profile.targetLossRate
        let thisWeekStalled = MacroCalculator.weekStalled(actualLossKg: actualWeightLost, targetLossKg: targetWeightLost)

        let checkIn = NutritionCheckIn(
            date: date,
            rollingAverageWeight: averageWeight,
            actualWeightLost: actualWeightLost,
            targetWeightLost: targetWeightLost
        )
        modelContext.insert(checkIn)
        checkIn.profile = profile

        // Cross-domain sync — one BodyMeasurement per day, updated on re-log.
        upsertBodyMeasurement(weightKg: averageWeight, date: date, note: "Weekly check-in")

        let startingPhase = profile.phase
        var macroAdjustmentApplied = false

        switch profile.phase {
        case .deficit:
            let enteredBreak = applyDietBreakProgression(profile, referenceDate: date)
            if !enteredBreak {
                macroAdjustmentApplied = applyPlateauCut(
                    profile,
                    thisWeekStalled: thisWeekStalled,
                    previousWeekStalled: previousCheckIn?.stalled == true
                )
            }
        case .dietBreak:
            _ = applyDietBreakProgression(profile, referenceDate: date)
        case .reverseDiet:
            applyReverseDietBump(profile, currentWeight: averageWeight)
        case .maintenance:
            break
        }

        checkIn.wasMacroAdjustmentApplied = macroAdjustmentApplied
        try modelContext.save()

        return WeeklyCheckInResult(
            actualWeightLost: actualWeightLost,
            targetWeightLost: targetWeightLost,
            stalled: thisWeekStalled,
            macroAdjustmentApplied: macroAdjustmentApplied,
            reachedGoal: profile.hasReachedGoal,
            phase: profile.phase,
            phaseChanged: profile.phase != startingPhase,
            newDailyCalories: profile.currentDailyCalories,
            newProteinGrams: profile.proteinTargetGrams,
            newCarbGrams: profile.carbTargetGrams,
            newFatGrams: profile.fatTargetGrams
        )
    }

    // MARK: - Edit & Override engine

    func updateProfile(profileID: PersistentIdentifier, newConfig: NutritionProfileConfig, manualMacros: (protein: Int, carbs: Int, fats: Int)?) async throws {
        guard let profile = self[profileID, as: NutritionProfile.self] else {
            throw NutritionRepositoryError.profileNotFound
        }

        // Update the input snapshot.
        profile.startingWeightKg = newConfig.startingWeightKg
        profile.goalWeightKg = newConfig.goalWeightKg
        profile.targetLossRate = newConfig.targetLossRate
        profile.bodyFatPercent = newConfig.bodyFatPercent
        profile.sex = newConfig.sex
        profile.ageYears = newConfig.ageYears
        profile.activity = newConfig.activity
        profile.proteinPreference = newConfig.proteinPref
        profile.resistanceTraining = newConfig.resistanceTraining

        if let manual = manualMacros {
            // Manual override: trust the user's numbers exactly.
            let calories = Double(manual.protein * 4 + manual.carbs * 4 + manual.fats * 9)
            let maintenance = MacroCalculator.maintenanceCalories(
                weightKg: newConfig.startingWeightKg, bodyFatPercent: newConfig.bodyFatPercent,
                sex: newConfig.sex, ageYears: newConfig.ageYears, activity: newConfig.activity
            )
            profile.proteinTargetGrams = Double(manual.protein)
            profile.carbTargetGrams = Double(manual.carbs)
            profile.fatTargetGrams = Double(manual.fats)
            profile.maintenanceCalories = maintenance
            profile.currentDailyCalories = calories
            profile.dailyDeficitKcal = maintenance - calories
        } else {
            // Re-run the deterministic pipeline at the new inputs.
            let input = DietInput(
                weightKg: newConfig.startingWeightKg, bodyFatPercent: newConfig.bodyFatPercent,
                sex: newConfig.sex, ageYears: newConfig.ageYears, weeklyLossRate: newConfig.targetLossRate,
                protein: newConfig.proteinPref, resistanceTraining: newConfig.resistanceTraining,
                activity: newConfig.activity
            )
            let rx = MacroCalculator.prescribe(input)
            profile.maintenanceCalories = rx.maintenanceKcal
            profile.currentDailyCalories = rx.startingDailyKcal
            profile.dailyDeficitKcal = rx.dailyDeficitKcal
            profile.proteinTargetGrams = rx.proteinGrams
            profile.carbTargetGrams = rx.carbGrams
            profile.fatTargetGrams = rx.fatGrams
        }

        try modelContext.save()
    }

    // MARK: - Daily quick-log engine (find-or-append)

    @discardableResult
    func logDailyMacros(profileID: PersistentIdentifier, protein: Int, carbs: Int, fats: Int, date: Date = Date()) async throws -> DailyMacroTotals {
        guard let profile = self[profileID, as: NutritionProfile.self] else {
            throw NutritionRepositoryError.profileNotFound
        }
        let day = Calendar.current.startOfDay(for: date)

        if let existing = profile.dailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            existing.proteinConsumed += protein
            existing.carbsConsumed += carbs
            existing.fatsConsumed += fats
            try modelContext.save()
            return DailyMacroTotals(protein: existing.proteinConsumed, carbs: existing.carbsConsumed, fats: existing.fatsConsumed)
        } else {
            let log = DailyMacroLog(date: day, proteinConsumed: protein, carbsConsumed: carbs, fatsConsumed: fats)
            modelContext.insert(log)
            log.profile = profile
            try modelContext.save()
            return DailyMacroTotals(protein: protein, carbs: carbs, fats: fats)
        }
    }

    // MARK: - Historical correction engine

    func updateHistoricalCheckIn(checkInID: PersistentIdentifier, newWeight: Double) async throws {
        guard let checkIn = self[checkInID, as: NutritionCheckIn.self] else {
            throw NutritionRepositoryError.checkInNotFound
        }
        let originalDate = checkIn.date
        checkIn.rollingAverageWeight = newWeight

        // Re-derive this week's loss vs the check-in immediately before it.
        if let profile = checkIn.profile {
            let prior = profile.checkIns
                .filter { $0.date < originalDate }
                .max(by: { $0.date < $1.date })
            let previousWeight = prior?.rollingAverageWeight ?? profile.startingWeightKg
            checkIn.actualWeightLost = previousWeight - newWeight
        }

        // Bonus: keep the Progress-tab BodyMeasurement for that day in sync.
        upsertBodyMeasurement(weightKg: newWeight, date: originalDate, note: nil)

        try modelContext.save()
    }

    // MARK: - Reverse diet / diet break / delete

    @discardableResult
    func evaluateDietBreak(profileID: PersistentIdentifier) async throws -> PhaseTransitionResult {
        guard let profile = self[profileID, as: NutritionProfile.self] else {
            throw NutritionRepositoryError.profileNotFound
        }
        let reference = profile.checkIns.map(\.date).max() ?? profile.createdAt
        let changed = applyDietBreakProgression(profile, referenceDate: reference)
        if changed { try modelContext.save() }
        return PhaseTransitionResult(phase: profile.phase, changed: changed, newDailyCalories: profile.currentDailyCalories)
    }

    @discardableResult
    func startReverseDiet(profileID: PersistentIdentifier) async throws -> PhaseTransitionResult {
        guard let profile = self[profileID, as: NutritionProfile.self] else {
            throw NutritionRepositoryError.profileNotFound
        }
        let weight = profile.latestWeightKg
        profile.maintenanceCalories = MacroCalculator.maintenanceCalories(
            weightKg: weight, bodyFatPercent: profile.bodyFatPercent,
            sex: profile.sex, ageYears: profile.ageYears, activity: profile.activity
        )
        profile.dailyDeficitKcal = max(0, profile.maintenanceCalories - profile.currentDailyCalories)
        profile.phase = .reverseDiet
        profile.phaseStartedAt = Date()
        try modelContext.save()
        return PhaseTransitionResult(phase: .reverseDiet, changed: true, newDailyCalories: profile.currentDailyCalories)
    }

    func deleteProfile(id: PersistentIdentifier) async throws {
        guard let profile = self[id, as: NutritionProfile.self] else { return }
        modelContext.delete(profile)   // cascades check-ins + daily logs
        try modelContext.save()
    }

    // MARK: - Cross-domain helper

    /// One BodyMeasurement per calendar day: update if present, else insert.
    /// Built and saved entirely on this actor's context — nothing crosses the
    /// boundary.
    private func upsertBodyMeasurement(weightKg: Double, date: Date, note: String?) {
        let day = Calendar.current.startOfDay(for: date)
        let all = (try? modelContext.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        if let existing = all.first(where: { Calendar.current.isDate($0.date, inSameDayAs: day) }) {
            existing.weightKG = weightKg
            if let note { existing.note = note }
        } else {
            modelContext.insert(BodyMeasurement(date: date, weightKG: weightKg, note: note))
        }
    }

    // MARK: - Private state-machine mutators

    private func applyPlateauCut(_ profile: NutritionProfile, thisWeekStalled: Bool, previousWeekStalled: Bool) -> Bool {
        guard thisWeekStalled, previousWeekStalled, profile.phase == .deficit else { return false }
        let reduced = MacroCalculator.reduceEnergyMacros(carbGrams: profile.carbTargetGrams, fatGrams: profile.fatTargetGrams, by: 0.10)
        let newCalories = profile.proteinTargetGrams * 4 + reduced.carbGrams * 4 + reduced.fatGrams * 9
        guard newCalories >= safetyFloorCalories else { return false }
        profile.carbTargetGrams = reduced.carbGrams
        profile.fatTargetGrams = reduced.fatGrams
        profile.currentDailyCalories = newCalories
        profile.dailyDeficitKcal = profile.maintenanceCalories - newCalories
        return true
    }

    private func applyDietBreakProgression(_ profile: NutritionProfile, referenceDate: Date) -> Bool {
        let days = Calendar.current.dateComponents([.day], from: profile.phaseStartedAt, to: referenceDate).day ?? 0
        let weeks = days / 7

        switch profile.phase {
        case .deficit where weeks >= dietBreakTriggerWeeks:
            let weight = profile.latestWeightKg
            let maintenance = MacroCalculator.maintenanceCalories(
                weightKg: weight, bodyFatPercent: profile.bodyFatPercent,
                sex: profile.sex, ageYears: profile.ageYears, activity: profile.activity
            )
            applyTargets(profile, totalCalories: maintenance, weight: weight, maintenance: maintenance)
            profile.phase = .dietBreak
            profile.phaseStartedAt = referenceDate
            return true

        case .dietBreak where weeks >= dietBreakLengthWeeks:
            represcribeDeficit(profile, weight: profile.latestWeightKg)
            profile.phase = .deficit
            profile.phaseStartedAt = referenceDate
            return true

        default:
            return false
        }
    }

    private func applyReverseDietBump(_ profile: NutritionProfile, currentWeight: Double) {
        let bumpedCarb = profile.carbTargetGrams * 1.05
        let bumpedFat = profile.fatTargetGrams * 1.05
        let newCalories = profile.proteinTargetGrams * 4 + bumpedCarb * 4 + bumpedFat * 9

        if newCalories >= profile.maintenanceCalories {
            applyTargets(profile, totalCalories: profile.maintenanceCalories, weight: currentWeight, maintenance: profile.maintenanceCalories)
            profile.phase = .maintenance
            profile.phaseStartedAt = Date()
        } else {
            profile.carbTargetGrams = bumpedCarb
            profile.fatTargetGrams = bumpedFat
            profile.currentDailyCalories = newCalories
            profile.dailyDeficitKcal = profile.maintenanceCalories - newCalories
        }
    }

    private func represcribeDeficit(_ profile: NutritionProfile, weight: Double) {
        let input = DietInput(
            weightKg: weight, bodyFatPercent: profile.bodyFatPercent, sex: profile.sex,
            ageYears: profile.ageYears, weeklyLossRate: profile.targetLossRate,
            protein: profile.proteinPreference, resistanceTraining: profile.resistanceTraining,
            activity: profile.activity
        )
        let rx = MacroCalculator.prescribe(input)
        profile.maintenanceCalories = rx.maintenanceKcal
        profile.currentDailyCalories = rx.startingDailyKcal
        profile.dailyDeficitKcal = rx.dailyDeficitKcal
        profile.proteinTargetGrams = rx.proteinGrams
        profile.carbTargetGrams = rx.carbGrams
        profile.fatTargetGrams = rx.fatGrams
    }

    private func applyTargets(_ profile: NutritionProfile, totalCalories: Double, weight: Double, maintenance: Double) {
        let m = MacroCalculator.macros(forCalories: totalCalories, weightKg: weight, protein: profile.proteinPreference)
        profile.maintenanceCalories = maintenance
        profile.currentDailyCalories = totalCalories
        profile.dailyDeficitKcal = maintenance - totalCalories
        profile.proteinTargetGrams = m.proteinGrams
        profile.carbTargetGrams = m.carbGrams
        profile.fatTargetGrams = m.fatGrams
    }
}
