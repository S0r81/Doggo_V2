//
//  BodyMeasurement.swift
//  Doggo_V2
//
//  A dated body-weight log entry for the Progress tab. Stored in kg and
//  converted for display, matching UserProfile.weightKG.
//

import Foundation
import SwiftData

@Model
class BodyMeasurement {
    var id: UUID
    var date: Date
    var weightKG: Double
    var note: String?

    init(date: Date = Date(), weightKG: Double, note: String? = nil) {
        self.id = UUID()
        self.date = date
        self.weightKG = weightKG
        self.note = note
    }
}
