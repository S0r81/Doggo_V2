//
//  PlateCalculatorZeroBarTests.swift
//  Doggo_V2Tests
//
//  Characterization + edge-case coverage for the "Machine / No Bar" preset
//  (0 lbs / 0 kg). Locks in that zero bar weight works perfectly and never
//  triggers a "below bar" false positive, a crash, or a negative loadout.
//

import Testing
@testable import Doggo_V2

struct PlateCalculatorZeroBarTests {

    private let lbsPlates = PlateCalculator.standardPlatesLbs
    private let kgPlates = PlateCalculator.standardPlatesKg

    // MARK: - BarType preset

    @Test func noBarPresetWeighsZeroInBothUnits() {
        #expect(BarType.noBar.weight(for: .imperial) == 0)
        #expect(BarType.noBar.weight(for: .metric) == 0)
        #expect(BarType.noBar.isBarless)
        #expect(!BarType.olympic.isBarless)
    }

    @Test func noBarIsExposedInAllCases() {
        #expect(BarType.allCases.contains(.noBar))
    }

    @Test func existingBarsAreUnchanged() {
        // Regression: adding the case must not shift any other bar's weight.
        #expect(BarType.olympic.weight(for: .imperial) == 45)
        #expect(BarType.olympic.weight(for: .metric) == 20)
        #expect(BarType.smithMachine.weight(for: .imperial) == 15)
    }

    // MARK: - Zero-bar math

    @Test func zeroBarLoadsFullTargetPerSide() {
        // 100 lbs on a no-bar machine → 50 per side → 45 + 5.
        let calc = PlateCalculator.calculate(target: 100, barWeight: 0, availablePlates: lbsPlates)
        #expect(calc.platesPerSide == [45, 5])
        #expect(calc.achievedWeight == 100)
        #expect(calc.isExact)
        #expect(!calc.targetBelowBar)
    }

    @Test func zeroBarNeverReportsBelowBar() {
        // With no bar there is no floor to be "below".
        for target in [1.0, 2.5, 5, 45, 225, 500] {
            let calc = PlateCalculator.calculate(target: target, barWeight: 0, availablePlates: lbsPlates)
            #expect(!calc.targetBelowBar, "target \(target) wrongly flagged below bar")
        }
    }

    @Test func zeroBarHeavyTargetGreedyIsOptimal() {
        // 225 → 112.5 per side → 45 + 45 + 10 + 10 + 2.5
        let calc = PlateCalculator.calculate(target: 225, barWeight: 0, availablePlates: lbsPlates)
        #expect(calc.platesPerSide == [45, 45, 10, 10, 2.5])
        #expect(calc.achievedWeight == 225)
        #expect(calc.isExact)
    }

    @Test func zeroBarOddTargetFallsShortGracefully() {
        // 2.5 lbs total → 1.25 per side → no plate fits; empty, not exact, no crash.
        let calc = PlateCalculator.calculate(target: 2.5, barWeight: 0, availablePlates: lbsPlates)
        #expect(calc.platesPerSide.isEmpty)
        #expect(!calc.isExact)
        #expect(calc.achievedWeight == 0)
        #expect(calc.shortfall == 2.5)
    }

    @Test func zeroBarZeroTargetIsEmptyAndSafe() {
        // Degenerate input must not crash or produce negative plates.
        let calc = PlateCalculator.calculate(target: 0, barWeight: 0, availablePlates: lbsPlates)
        #expect(calc.platesPerSide.isEmpty)
        #expect(calc.achievedWeight == 0)
        #expect(!calc.targetBelowBar)
        #expect(calc.platesPerSide.allSatisfy { $0 > 0 })
    }

    @Test func zeroBarMetricExactLoad() {
        // 60 kg no bar → 30 per side → 25 + 5
        let calc = PlateCalculator.calculate(target: 60, barWeight: 0, availablePlates: kgPlates)
        #expect(calc.platesPerSide == [25, 5])
        #expect(calc.achievedWeight == 60)
        #expect(calc.isExact)
    }

    @Test func zeroBarNoAvailablePlatesDoesNotCrash() {
        // Empty plate set is a valid (if useless) gym config.
        let calc = PlateCalculator.calculate(target: 100, barWeight: 0, availablePlates: [])
        #expect(calc.platesPerSide.isEmpty)
        #expect(calc.shortfall == 100)
        #expect(!calc.targetBelowBar)
    }
}
