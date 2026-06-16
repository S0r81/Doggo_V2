//
//  PeptideCalculator.swift
//  Doggo_V2
//
//  Pure reconstitution math for subcutaneous peptide dosing on a U-100
//  insulin syringe. Given a vial amount, the bacteriostatic water added, and a
//  desired dose, it tells the user exactly how many syringe "units" (tick
//  marks) to draw — now unit-aware so HGH (IU) works alongside mg/mcg peptides.
//
//  A U-100 syringe ALWAYS holds 1 ml across 100 units (1 unit = 0.01 ml).
//  The dose's unit is the working unit: vial amount is converted into that
//  unit, divided by water to get concentration-per-ml, then per-unit.
//
//  Worked examples:
//    5 mg vial + 2 ml, dose in mcg → 5000 mcg / 2 = 2500 mcg/ml → 25 mcg/unit
//        → 250 mcg pulls to 10 units
//    100 IU vial + 1 ml, dose in IU → 100 / 1 = 100 IU/ml → 1 IU/unit
//        → 10 IU pulls to 10 units
//

import Foundation

/// The unit a vial or dose is measured in.
enum PeptideMeasurementUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case mg
    case mcg
    case iu

    var id: String { rawValue }

    var label: String {
        switch self {
        case .mg: return "mg"
        case .mcg: return "mcg"
        case .iu: return "IU"
        }
    }

    /// mg and mcg are interchangeable mass units; IU is its own family and
    /// can only convert to IU (no compound-independent IU↔mass factor exists).
    var isMass: Bool { self == .mg || self == .mcg }

    /// How many mcg one of this unit equals (nil for IU).
    var mcgEquivalent: Double? {
        switch self {
        case .mg: return 1000
        case .mcg: return 1
        case .iu: return nil
        }
    }
}

struct PeptideCalculation {
    let vialAmount: Double
    let vialUnit: PeptideMeasurementUnit
    let waterAddedMl: Double
    let doseAmount: Double
    let doseUnit: PeptideMeasurementUnit

    /// Whether the vial unit can be expressed in the dose unit at all.
    var unitsCompatible: Bool {
        PeptideCalculator.conversionFactor(from: vialUnit, to: doseUnit) != nil
    }

    /// Every input positive AND the two units convertible.
    var isValid: Bool {
        vialAmount > 0 && waterAddedMl > 0 && doseAmount > 0 && unitsCompatible
    }

    /// Vial amount expressed in the dose's unit (nil when incompatible).
    private var vialInDoseUnit: Double? {
        guard let factor = PeptideCalculator.conversionFactor(from: vialUnit, to: doseUnit) else { return nil }
        return vialAmount * factor
    }

    /// Concentration after reconstitution, in dose-units per ml.
    var concentrationPerMl: Double {
        guard waterAddedMl > 0, let vial = vialInDoseUnit else { return 0 }
        return vial / waterAddedMl
    }

    /// Dose-units delivered per single syringe tick.
    var perUnitAmount: Double { concentrationPerMl * PeptideCalculator.mlPerUnit }

    /// The precise number of units to pull for the desired dose.
    var unitsToPull: Double {
        guard perUnitAmount > 0 else { return 0 }
        return doseAmount / perUnitAmount
    }

    /// Volume drawn for the desired dose, in ml.
    var volumeToPullMl: Double { unitsToPull * PeptideCalculator.mlPerUnit }

    /// The pull rounded to the nearest measurable whole tick — what the user
    /// actually draws.
    var roundedUnits: Int { Int(unitsToPull.rounded()) }

    /// The dose actually delivered once the pull is rounded to a whole tick.
    var deliveredDose: Double { Double(roundedUnits) * perUnitAmount }

    /// True when the desired dose lands exactly on a tick mark.
    var isExactTick: Bool { abs(unitsToPull - unitsToPull.rounded()) < 0.01 }

    /// Whole doses available before the vial runs dry.
    var dosesPerVial: Int {
        guard doseAmount > 0, let vial = vialInDoseUnit else { return 0 }
        return Int((vial / doseAmount).rounded(.down))
    }

    /// Unit label for per-ml / per-unit readouts (the dose unit).
    var unitLabel: String { doseUnit.label }
}

enum PeptideCalculator {

    /// A U-100 syringe spans 100 units across 1 ml.
    static let unitsPerMl: Double = 100
    static let mlPerUnit: Double = 1.0 / unitsPerMl   // 0.01 ml

    /// Amount in `from` × factor = equivalent amount in `to`. nil when the
    /// units belong to different families (any IU ↔ mg/mcg mix).
    static func conversionFactor(from: PeptideMeasurementUnit, to: PeptideMeasurementUnit) -> Double? {
        if from == to { return 1 }
        guard let fromMcg = from.mcgEquivalent, let toMcg = to.mcgEquivalent else { return nil }
        return fromMcg / toMcg   // e.g. mg→mcg = 1000 / 1 = 1000
    }

    /// Unit-aware calculation.
    static func calculate(
        vialAmount: Double,
        vialUnit: PeptideMeasurementUnit,
        waterAddedMl: Double,
        doseAmount: Double,
        doseUnit: PeptideMeasurementUnit
    ) -> PeptideCalculation {
        PeptideCalculation(
            vialAmount: vialAmount,
            vialUnit: vialUnit,
            waterAddedMl: waterAddedMl,
            doseAmount: doseAmount,
            doseUnit: doseUnit
        )
    }

    /// Backward-compatible entry point: mg vial, mcg dose. Keeps existing
    /// callers (PeptideProfile.calculation, dashboard, notifications) working.
    static func calculate(
        totalMg: Double,
        waterAddedMl: Double,
        desiredDoseMcg: Double
    ) -> PeptideCalculation {
        calculate(
            vialAmount: totalMg,
            vialUnit: .mg,
            waterAddedMl: waterAddedMl,
            doseAmount: desiredDoseMcg,
            doseUnit: .mcg
        )
    }

    /// Trims trailing ".0" — "10" not "10.0", but keeps "12.5".
    static func format(_ value: Double, maxDecimals: Int = 2) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(format: "%.\(maxDecimals)g", value)
    }
}
