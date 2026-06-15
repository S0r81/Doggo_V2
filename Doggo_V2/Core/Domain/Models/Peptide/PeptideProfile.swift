//
//  PeptideProfile.swift
//  Doggo_V2
//
//  A reconstituted peptide vial the user is running (e.g. "BPC-157", 5mg in
//  2ml). Owns one active schedule and a history of logged injections.
//

import Foundation
import SwiftData

@Model
final class PeptideProfile {
    var id: UUID
    var name: String
    /// Amount of peptide in the vial, expressed in `vialUnit` (the legacy
    /// `totalMg` name is kept for store stability; it may hold mg or IU).
    var totalMg: Double
    /// Bacteriostatic water added to reconstitute, in millilitres.
    var waterAddedMl: Double
    var createdAt: Date
    /// Archived profiles stay for history but stop generating reminders.
    var isActive: Bool

    /// Vial measurement unit ("mg" / "iu"). String-backed for migration
    /// safety; new rows default to mg. See `vialUnit` for the typed view.
    var vialUnitRaw: String = PeptideMeasurementUnit.mg.rawValue

    @Relationship(deleteRule: .cascade, inverse: \PeptideSchedule.profile)
    var schedule: PeptideSchedule?

    @Relationship(deleteRule: .cascade, inverse: \PeptideLog.profile)
    var logs: [PeptideLog] = []

    init(
        name: String,
        totalMg: Double,
        waterAddedMl: Double,
        vialUnit: PeptideMeasurementUnit = .mg,
        isActive: Bool = true
    ) {
        self.id = UUID()
        self.name = name
        self.totalMg = totalMg
        self.waterAddedMl = waterAddedMl
        self.vialUnitRaw = vialUnit.rawValue
        self.createdAt = Date()
        self.isActive = isActive
    }
}

extension PeptideProfile {
    /// Typed view over the stored vial unit.
    var vialUnit: PeptideMeasurementUnit {
        get { PeptideMeasurementUnit(rawValue: vialUnitRaw) ?? .mg }
        set { vialUnitRaw = newValue.rawValue }
    }

    /// The reconstitution math for this vial against its scheduled target dose,
    /// honoring both the vial unit and the schedule's dose unit. Returns nil
    /// until a schedule with a target dose exists.
    var calculation: PeptideCalculation? {
        guard let schedule, schedule.targetDoseMcg > 0 else { return nil }
        return PeptideCalculator.calculate(
            vialAmount: totalMg,
            vialUnit: vialUnit,
            waterAddedMl: waterAddedMl,
            doseAmount: schedule.targetDoseMcg,
            doseUnit: schedule.doseUnit
        )
    }
}
