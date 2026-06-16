//
//  MacroCalculator.swift
//  Doggo_V2
//
//  Phase 1 of the Diet Planner: the pure, deterministic math engine. No UI, no
//  SwiftData — just value types and switch statements, so it is trivially
//  testable and reusable from any actor.
//
//  Every constant is sourced from Norton & Hill, "Fat Loss Forever":
//    · Müller BMR equation .......... p.53
//    · Body-fat classification ....... Table 1, p.130
//    · FM/LBM loss ratios ............ Table 1, p.130
//    · Deficit multipliers (kcal/kg) . Table 2, p.136
//    · Rate-of-loss bands (0.4–1.0%) . p.128, p.139
//    · Protein targets ............... p.172 (2.2 g/kg BW for high protein)
//    · BMR ≈ 60% of TDEE ............. p.40 (maintenance derivation rationale)
//
//  The deficit is computed as weeklyLossKg × Table 2 multiplier, which the book
//  uses to reproduce its worked examples (p.137):
//    100 kg male, Normal, HP+RT, 0.6%/wk → 0.6 × 930  = 558  kcal/day
//     90 kg female, Overweight, HP+RT, 1.0%/wk → 0.9 × 1024 = 921.6 → 922
//

import Foundation

// MARK: - Inputs

enum BiologicalSex: String, Sendable, CaseIterable {
    case male
    case female
}

/// Normal-protein diet (<1.6 g/kg) vs high-protein diet (≥1.6 g/kg) — the book's
/// NP/HP split that keys both Table 1 and Table 2.
enum ProteinPreference: String, Sendable, CaseIterable {
    case normal
    case high
}

/// Body-fat classification per Table 1 boundaries (p.130).
enum BodyFatClass: String, Sendable, CaseIterable {
    case lean
    case normal
    case overweight
    case obese
}

/// Standard activity multipliers applied to BMR to estimate maintenance (TDEE).
/// The book stresses maintenance is best found empirically (p.126); this is the
/// formula fallback when no tracking history exists.
enum ActivityLevel: String, Sendable, CaseIterable {
    case sedentary
    case light
    case moderate
    case active
    case veryActive

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.20
        case .light: return 1.375
        case .moderate: return 1.55
        case .active: return 1.725
        case .veryActive: return 1.90
        }
    }
}

struct DietInput: Sendable {
    var weightKg: Double
    var bodyFatPercent: Double
    var sex: BiologicalSex
    /// Required by the Müller BMR equation.
    var ageYears: Int
    /// Target weekly loss as a fraction of bodyweight (0.006 = 0.6%). Clamped to
    /// 0.004…0.010 by the pipeline.
    var weeklyLossRate: Double
    var protein: ProteinPreference
    var resistanceTraining: Bool
    /// Only affects the maintenance estimate, never the deficit.
    var activity: ActivityLevel

    init(
        weightKg: Double,
        bodyFatPercent: Double,
        sex: BiologicalSex,
        ageYears: Int = 30,
        weeklyLossRate: Double,
        protein: ProteinPreference,
        resistanceTraining: Bool,
        activity: ActivityLevel = .moderate
    ) {
        self.weightKg = weightKg
        self.bodyFatPercent = bodyFatPercent
        self.sex = sex
        self.ageYears = ageYears
        self.weeklyLossRate = weeklyLossRate
        self.protein = protein
        self.resistanceTraining = resistanceTraining
        self.activity = activity
    }
}

// MARK: - Output

struct DietPrescription: Sendable {
    let classification: BodyFatClass

    /// Table 1 split of where the lost weight comes from.
    let fmLossFraction: Double
    let lbmLossFraction: Double

    let clampedWeeklyLossRate: Double
    let weeklyWeightLossKg: Double

    /// Table 2 multiplier used (kcal of daily deficit per kg of weekly loss).
    let deficitMultiplierKcalPerKg: Double
    /// Exact daily deficit (e.g. 558.0, 921.6).
    let dailyDeficitKcal: Double

    let bmrKcal: Double
    let maintenanceKcal: Double
    /// maintenance − deficit.
    let startingDailyKcal: Double

    let proteinGrams: Double
    let proteinKcal: Double
    /// Calories left for carbs + fat after protein is set as a floor.
    let remainingKcalForCarbsFats: Double
    /// The remainder split into grams: fat takes ~25% of total calories (the
    /// book's 20–30% hormonal band), carbs fill the rest.
    let carbGrams: Double
    let fatGrams: Double

    /// Daily deficit rounded to whole calories (558, 922).
    var dailyDeficitKcalRounded: Int { Int(dailyDeficitKcal.rounded()) }
}

// MARK: - Engine

enum MacroCalculator {

    // Rate-of-loss guardrails (p.128, p.139).
    static let minWeeklyLossRate = 0.004
    static let maxWeeklyLossRate = 0.010

    // High-protein target, g per kg bodyweight (p.172: "2.2 g/kg ≈ 1 g/lb").
    static let highProteinPerKg = 2.2
    // Normal-protein representative target (NP band is <1.6 g/kg).
    static let normalProteinPerKg = 1.2

    // MARK: Classification — Table 1 boundaries (p.130)

    static func classify(bodyFatPercent bf: Double, sex: BiologicalSex) -> BodyFatClass {
        switch sex {
        case .male:
            if bf > 27 { return .obese }
            if bf > 22 { return .overweight }
            if bf >= 11 { return .normal }
            return .lean
        case .female:
            if bf > 40 { return .obese }
            if bf > 35 { return .overweight }
            if bf >= 23 { return .normal }
            return .lean
        }
    }

    // MARK: Table 1 — fraction of lost weight that is fat mass (p.130)

    static func fmLossFraction(
        _ population: BodyFatClass,
        protein: ProteinPreference,
        resistanceTraining: Bool
    ) -> Double {
        switch (population, protein, resistanceTraining) {
        // Obese — book lists ">90/<10" for HP+RT; encoded as 0.90.
        case (.obese, .normal, false): return 0.80
        case (.obese, .high, false): return 0.90
        case (.obese, .normal, true): return 0.90
        case (.obese, .high, true): return 0.90
        // Overweight
        case (.overweight, .normal, false): return 0.70
        case (.overweight, .high, false): return 0.80
        case (.overweight, .normal, true): return 0.80
        case (.overweight, .high, true): return 0.90
        // Normal
        case (.normal, .normal, false): return 0.60
        case (.normal, .high, false): return 0.70
        case (.normal, .normal, true): return 0.70
        case (.normal, .high, true): return 0.80
        // Lean — book lists "<50/>50" for NP+NoRT; encoded as 0.50.
        case (.lean, .normal, false): return 0.50
        case (.lean, .high, false): return 0.60
        case (.lean, .normal, true): return 0.60
        case (.lean, .high, true): return 0.70
        }
    }

    // MARK: Table 2 — daily deficit multiplier, kcal per kg of weekly loss (p.136)

    static func deficitMultiplier(
        _ population: BodyFatClass,
        protein: ProteinPreference,
        resistanceTraining: Bool
    ) -> Double {
        switch (population, protein, resistanceTraining) {
        // Obese — book gives a range "1024–1120" for HP+RT; upper bound used,
        // since obese individuals lose the highest fat fraction.
        case (.obese, .normal, false): return 930
        case (.obese, .high, false): return 1024
        case (.obese, .normal, true): return 1024
        case (.obese, .high, true): return 1120
        // Overweight
        case (.overweight, .normal, false): return 834
        case (.overweight, .high, false): return 930
        case (.overweight, .normal, true): return 930
        case (.overweight, .high, true): return 1024
        // Normal
        case (.normal, .normal, false): return 740
        case (.normal, .high, false): return 834
        case (.normal, .normal, true): return 834
        case (.normal, .high, true): return 930
        // Lean
        case (.lean, .normal, false): return 645
        case (.lean, .high, false): return 740
        case (.lean, .normal, true): return 740
        case (.lean, .high, true): return 834
        }
    }

    // MARK: Müller BMR (p.53)

    /// BMR = 13.587·FFM + 9.613·FM + 198·(sex: male 1 / female 0) − 3.351·age + 674.
    /// FFM and FM in kg, age in years. Reproduces the book's worked value of
    /// 2118 kcal for FFM 87.65, FM 15.2, male, age 27.
    static func mullerBMR(
        fatFreeMassKg ffm: Double,
        fatMassKg fm: Double,
        sex: BiologicalSex,
        ageYears age: Int
    ) -> Double {
        let sexFactor = (sex == .male) ? 1.0 : 0.0
        return 13.587 * ffm
            + 9.613 * fm
            + 198 * sexFactor
            - 3.351 * Double(age)
            + 674
    }

    // MARK: Pipeline

    static func prescribe(_ input: DietInput) -> DietPrescription {
        // 1. Classify and pull both table values off that single classification.
        let population = classify(bodyFatPercent: input.bodyFatPercent, sex: input.sex)
        let fmFraction = fmLossFraction(population, protein: input.protein, resistanceTraining: input.resistanceTraining)
        let multiplier = deficitMultiplier(population, protein: input.protein, resistanceTraining: input.resistanceTraining)

        // 2. Clamp the rate, derive weekly loss and the daily deficit.
        let rate = min(max(input.weeklyLossRate, minWeeklyLossRate), maxWeeklyLossRate)
        let weeklyLossKg = input.weightKg * rate
        let dailyDeficit = weeklyLossKg * multiplier

        // 3. Müller BMR → maintenance (TDEE) → starting calories.
        let fatMassKg = input.weightKg * input.bodyFatPercent / 100
        let fatFreeMassKg = input.weightKg - fatMassKg
        let bmr = mullerBMR(
            fatFreeMassKg: fatFreeMassKg,
            fatMassKg: fatMassKg,
            sex: input.sex,
            ageYears: input.ageYears
        )
        let maintenance = bmr * input.activity.multiplier
        let startingDaily = maintenance - dailyDeficit

        // 4. Protein floor first, then carbs/fat get the remainder.
        let proteinPerKg = (input.protein == .high) ? highProteinPerKg : normalProteinPerKg
        let proteinGrams = input.weightKg * proteinPerKg
        let proteinKcal = proteinGrams * 4
        let remaining = startingDaily - proteinKcal

        // Split the carb/fat remainder: fat ~25% of total calories, carbs rest.
        let pool = max(0, remaining)
        let fatKcal = min(0.25 * startingDaily, pool)
        let fatGrams = fatKcal / 9
        let carbGrams = (pool - fatKcal) / 4

        return DietPrescription(
            classification: population,
            fmLossFraction: fmFraction,
            lbmLossFraction: 1 - fmFraction,
            clampedWeeklyLossRate: rate,
            weeklyWeightLossKg: weeklyLossKg,
            deficitMultiplierKcalPerKg: multiplier,
            dailyDeficitKcal: dailyDeficit,
            bmrKcal: bmr,
            maintenanceKcal: maintenance,
            startingDailyKcal: startingDaily,
            proteinGrams: proteinGrams,
            proteinKcal: proteinKcal,
            remainingKcalForCarbsFats: remaining,
            carbGrams: carbGrams,
            fatGrams: fatGrams
        )
    }

    // MARK: - Plateau primitives (pure — used by the diet-planner state loop)

    /// Cuts the energy macros (carbs + fat) by `fraction`, leaving protein
    /// untouched — the book's plateau adjustment ("10–20% drop in carbs and
    /// fats", p.234).
    static func reduceEnergyMacros(
        carbGrams: Double,
        fatGrams: Double,
        by fraction: Double
    ) -> (carbGrams: Double, fatGrams: Double) {
        let keep = 1 - fraction
        return (carbGrams * keep, fatGrams * keep)
    }

    /// A week "stalled" when actual loss falls below `threshold` (default 50%)
    /// of the targeted loss. Zero/negative loss always counts as stalled.
    static func weekStalled(
        actualLossKg: Double,
        targetLossKg: Double,
        threshold: Double = 0.5
    ) -> Bool {
        guard targetLossKg > 0 else { return false }
        return actualLossKg < threshold * targetLossKg
    }

    /// Estimated maintenance (TDEE) at a given weight — used to recompute the
    /// anchor when weight changes (diet breaks, reverse-diet targets).
    static func maintenanceCalories(
        weightKg: Double,
        bodyFatPercent: Double,
        sex: BiologicalSex,
        ageYears: Int,
        activity: ActivityLevel
    ) -> Double {
        let fatMass = weightKg * bodyFatPercent / 100
        let fatFreeMass = weightKg - fatMass
        return mullerBMR(fatFreeMassKg: fatFreeMass, fatMassKg: fatMass, sex: sex, ageYears: ageYears)
            * activity.multiplier
    }

    /// Splits a calorie total into macro grams: protein floor first, fat ~25%
    /// of total, carbs fill the rest. Used when re-targeting at maintenance.
    static func macros(
        forCalories total: Double,
        weightKg: Double,
        protein: ProteinPreference
    ) -> (proteinGrams: Double, carbGrams: Double, fatGrams: Double) {
        let proteinPerKg = (protein == .high) ? highProteinPerKg : normalProteinPerKg
        let proteinGrams = weightKg * proteinPerKg
        let pool = max(0, total - proteinGrams * 4)
        let fatKcal = min(0.25 * total, pool)
        return (proteinGrams, (pool - fatKcal) / 4, fatKcal / 9)
    }
}
