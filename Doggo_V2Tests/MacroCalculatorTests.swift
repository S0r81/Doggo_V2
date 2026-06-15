//
//  MacroCalculatorTests.swift
//  Doggo_V2Tests
//
//  Locks the deterministic diet math to the two worked examples in
//  "Fat Loss Forever" (p.137) plus the Müller BMR value (p.53). If a refactor
//  ever drifts the deficit off 558 / 922, these fail loudly.
//

import Testing
@testable import Doggo_V2

struct MacroCalculatorTests {

    // MARK: - The two book worked examples (the load-bearing assertions)

    @Test func bookExample1_100kgMale_normal_HPRT_0point6pct() {
        // p.137: 100 kg male, 20% BF, high protein + resistance training,
        // targeting 0.6%/week → 0.6 kg × 930 kcal/kg = 558 kcal/day.
        let input = DietInput(
            weightKg: 100,
            bodyFatPercent: 20,
            sex: .male,
            weeklyLossRate: 0.006,
            protein: .high,
            resistanceTraining: true
        )
        let rx = MacroCalculator.prescribe(input)

        #expect(rx.classification == .normal)
        #expect(rx.deficitMultiplierKcalPerKg == 930)
        #expect(rx.weeklyWeightLossKg == 0.6)
        #expect(rx.dailyDeficitKcal == 558.0)
        #expect(rx.dailyDeficitKcalRounded == 558)
        // Table 1: Normal + HP + RT → 80/20.
        #expect(rx.fmLossFraction == 0.80)
        #expect(abs(rx.lbmLossFraction - 0.20) < 1e-9)
    }

    @Test func bookExample2_90kgFemale_overweight_HPRT_1pct() {
        // p.137: 90 kg female, 36% BF, high protein + resistance training,
        // targeting 1.0%/week → 0.9 kg × 1024 kcal/kg = 921.6 → 922 kcal/day.
        let input = DietInput(
            weightKg: 90,
            bodyFatPercent: 36,
            sex: .female,
            weeklyLossRate: 0.010,
            protein: .high,
            resistanceTraining: true
        )
        let rx = MacroCalculator.prescribe(input)

        #expect(rx.classification == .overweight)
        #expect(rx.deficitMultiplierKcalPerKg == 1024)
        #expect(rx.weeklyWeightLossKg == 0.9)
        #expect(abs(rx.dailyDeficitKcal - 921.6) < 0.0001)
        #expect(rx.dailyDeficitKcalRounded == 922)
        // Table 1: Overweight + HP + RT → 90/10.
        #expect(rx.fmLossFraction == 0.90)
        #expect(abs(rx.lbmLossFraction - 0.10) < 1e-9)
    }

    // MARK: - Müller BMR (p.53)

    @Test func mullerBMRMatchesBookWorkedValue() {
        // Book pre-diet calc: FFM 87.65, FM 15.2, male, age 27 → 2118 kcal.
        let bmr = MacroCalculator.mullerBMR(
            fatFreeMassKg: 87.65,
            fatMassKg: 15.2,
            sex: .male,
            ageYears: 27
        )
        #expect(abs(bmr - 2118) < 1.0)
    }

    @Test func mullerSexTermDropsForFemale() {
        // Female loses the +198 male term, all else equal.
        let male = MacroCalculator.mullerBMR(fatFreeMassKg: 50, fatMassKg: 15, sex: .male, ageYears: 30)
        let female = MacroCalculator.mullerBMR(fatFreeMassKg: 50, fatMassKg: 15, sex: .female, ageYears: 30)
        #expect(abs((male - female) - 198) < 0.0001)
    }

    // MARK: - Classification boundaries (Table 1, p.130)

    @Test func classificationBoundaries() {
        #expect(MacroCalculator.classify(bodyFatPercent: 9, sex: .male) == .lean)
        #expect(MacroCalculator.classify(bodyFatPercent: 11, sex: .male) == .normal)
        #expect(MacroCalculator.classify(bodyFatPercent: 20, sex: .male) == .normal)   // the book's example
        #expect(MacroCalculator.classify(bodyFatPercent: 22, sex: .male) == .normal)   // inclusive top
        #expect(MacroCalculator.classify(bodyFatPercent: 25, sex: .male) == .overweight)
        #expect(MacroCalculator.classify(bodyFatPercent: 30, sex: .male) == .obese)

        #expect(MacroCalculator.classify(bodyFatPercent: 20, sex: .female) == .lean)
        #expect(MacroCalculator.classify(bodyFatPercent: 30, sex: .female) == .normal)
        #expect(MacroCalculator.classify(bodyFatPercent: 36, sex: .female) == .overweight) // the book's example
        #expect(MacroCalculator.classify(bodyFatPercent: 45, sex: .female) == .obese)
    }

    // MARK: - Table spot-checks (the corners that aren't in the worked examples)

    @Test func deficitMultiplierTableCorners() {
        #expect(MacroCalculator.deficitMultiplier(.lean, protein: .normal, resistanceTraining: false) == 645)
        #expect(MacroCalculator.deficitMultiplier(.lean, protein: .high, resistanceTraining: true) == 834)
        #expect(MacroCalculator.deficitMultiplier(.obese, protein: .high, resistanceTraining: true) == 1120)
        #expect(MacroCalculator.deficitMultiplier(.normal, protein: .normal, resistanceTraining: false) == 740)
    }

    @Test func fmLossFractionTableCorners() {
        #expect(MacroCalculator.fmLossFraction(.lean, protein: .normal, resistanceTraining: false) == 0.50)
        #expect(MacroCalculator.fmLossFraction(.obese, protein: .high, resistanceTraining: true) == 0.90)
        #expect(MacroCalculator.fmLossFraction(.normal, protein: .high, resistanceTraining: true) == 0.80)
    }

    // MARK: - Rate clamping (p.128 max 1%, p.139 min 0.4%)

    @Test func rateClampsToBookBands() {
        // Above 1.0% clamps down to 1.0%.
        let hot = DietInput(weightKg: 100, bodyFatPercent: 20, sex: .male,
                            weeklyLossRate: 0.05, protein: .high, resistanceTraining: true)
        #expect(MacroCalculator.prescribe(hot).clampedWeeklyLossRate == 0.010)

        // Below 0.4% clamps up to 0.4%.
        let cold = DietInput(weightKg: 100, bodyFatPercent: 20, sex: .male,
                             weeklyLossRate: 0.001, protein: .high, resistanceTraining: true)
        #expect(MacroCalculator.prescribe(cold).clampedWeeklyLossRate == 0.004)
    }

    // MARK: - Macro allocation wiring

    @Test func proteinFloorAndRemainderAreConsistent() {
        let input = DietInput(weightKg: 100, bodyFatPercent: 20, sex: .male,
                              weeklyLossRate: 0.006, protein: .high, resistanceTraining: true)
        let rx = MacroCalculator.prescribe(input)

        // High protein → 2.2 g/kg BW (p.172).
        #expect(abs(rx.proteinGrams - 220) < 1e-9)
        #expect(abs(rx.proteinKcal - 880) < 1e-9)
        // The pieces add up: maintenance − deficit = protein + remainder.
        #expect(abs(rx.startingDailyKcal - (rx.maintenanceKcal - rx.dailyDeficitKcal)) < 0.0001)
        #expect(abs((rx.proteinKcal + rx.remainingKcalForCarbsFats) - rx.startingDailyKcal) < 0.0001)
    }

    // MARK: - Carb/fat split + plateau primitives (Phase 2 building blocks)

    @Test func carbFatSplitReconstitutesTheRemainder() {
        let rx = MacroCalculator.prescribe(DietInput(
            weightKg: 100, bodyFatPercent: 20, sex: .male,
            weeklyLossRate: 0.006, protein: .high, resistanceTraining: true
        ))
        // carbs·4 + fat·9 == the carb/fat calorie pool.
        #expect(abs((rx.carbGrams * 4 + rx.fatGrams * 9) - rx.remainingKcalForCarbsFats) < 1e-6)
        // Fat takes ~25% of total starting calories.
        #expect(abs(rx.fatGrams * 9 - 0.25 * rx.startingDailyKcal) < 1e-6)
    }

    @Test func weekStalledThreshold() {
        #expect(MacroCalculator.weekStalled(actualLossKg: 0.1, targetLossKg: 0.6))   // 0.1 < 0.3
        #expect(!MacroCalculator.weekStalled(actualLossKg: 0.4, targetLossKg: 0.6))  // 0.4 ≥ 0.3
        #expect(!MacroCalculator.weekStalled(actualLossKg: 0.3, targetLossKg: 0.6))  // exactly 50% is not a stall
        #expect(MacroCalculator.weekStalled(actualLossKg: -0.2, targetLossKg: 0.6))  // gained weight
        #expect(!MacroCalculator.weekStalled(actualLossKg: 0, targetLossKg: 0))      // no target → not stalled
    }

    @Test func reduceEnergyMacrosLeavesProteinUntouched() {
        let r = MacroCalculator.reduceEnergyMacros(carbGrams: 200, fatGrams: 60, by: 0.10)
        #expect(abs(r.carbGrams - 180) < 1e-9)
        #expect(abs(r.fatGrams - 54) < 1e-9)
    }
}
