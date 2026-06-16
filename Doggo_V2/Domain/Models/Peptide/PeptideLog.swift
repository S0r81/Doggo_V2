//
//  PeptideLog.swift
//  Doggo_V2
//
//  A single recorded injection. The dose is snapshotted in mcg so editing a
//  profile's schedule later never rewrites past history.
//

import Foundation
import SwiftData

@Model
final class PeptideLog {
    var id: UUID
    var date: Date
    /// Dose amount taken, expressed in `doseUnit` (the legacy `doseTakenMcg`
    /// name is kept for store stability; it may hold mcg, mg, or IU).
    var doseTakenMcg: Double
    /// Unit snapshotted at log time so history stays accurate even if the
    /// profile's dose unit changes later. String-backed for migration safety.
    var doseUnitRaw: String = PeptideMeasurementUnit.mcg.rawValue
    var note: String?

    var profile: PeptideProfile?

    init(date: Date = Date(), doseTakenMcg: Double, doseUnit: PeptideMeasurementUnit = .mcg, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.doseTakenMcg = doseTakenMcg
        self.doseUnitRaw = doseUnit.rawValue
        self.note = note
    }
}

extension PeptideLog {
    /// Typed view over the stored dose unit.
    var doseUnit: PeptideMeasurementUnit {
        get { PeptideMeasurementUnit(rawValue: doseUnitRaw) ?? .mcg }
        set { doseUnitRaw = newValue.rawValue }
    }
}
