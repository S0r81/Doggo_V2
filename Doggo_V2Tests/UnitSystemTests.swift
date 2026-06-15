//
//  UnitSystemTests.swift
//  Doggo_V2Tests
//
//  Locks the single weight-conversion factor so the value can never drift back
//  to the inconsistent 2.20462 / 2.2046226 / 0.453592 constants it replaced.
//

import Testing
@testable import Doggo_V2

struct UnitSystemTests {

    @Test func exactFactorMatchesNIST() {
        #expect(UnitSystem.kilogramsPerPound == 0.45359237)
        #expect(abs(UnitSystem.poundsPerKilogram - 2.2046226218) < 1e-9)
    }

    @Test func imperialRoundTripIsLossless() {
        let kg = 83.7
        let lbs = UnitSystem.imperial.displayWeight(fromKg: kg)
        #expect(abs(lbs - 184.527) < 0.001)                     // 83.7 / 0.45359237
        #expect(abs(UnitSystem.imperial.kilograms(fromDisplay: lbs) - kg) < 1e-9)
    }

    @Test func metricIsIdentity() {
        #expect(UnitSystem.metric.displayWeight(fromKg: 72) == 72)
        #expect(UnitSystem.metric.kilograms(fromDisplay: 72) == 72)
    }

    @Test func formattedWeightCarriesUnitAndPrecision() {
        #expect(UnitSystem.imperial.formattedWeight(fromKg: 100) == "220.5 lbs")
        #expect(UnitSystem.metric.formattedWeight(fromKg: 100, decimals: 0) == "100 kg")
    }
}
