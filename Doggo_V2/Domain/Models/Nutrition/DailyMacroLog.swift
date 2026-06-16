//
//  DailyMacroLog.swift
//  Doggo_V2
//
//  One day's running total of macros actually consumed. Quick-logs append to
//  the existing row for the day (see NutritionRepository.logDailyMacros), so
//  there is at most one DailyMacroLog per calendar day per profile.
//

import Foundation
import SwiftData

@Model
final class DailyMacroLog {
    var id: UUID
    /// Truncated to the start of the day it represents.
    var date: Date
    var proteinConsumed: Int
    var carbsConsumed: Int
    var fatsConsumed: Int

    var profile: NutritionProfile?

    init(
        date: Date,
        proteinConsumed: Int = 0,
        carbsConsumed: Int = 0,
        fatsConsumed: Int = 0
    ) {
        self.id = UUID()
        self.date = Calendar.current.startOfDay(for: date)
        self.proteinConsumed = proteinConsumed
        self.carbsConsumed = carbsConsumed
        self.fatsConsumed = fatsConsumed
    }
}
