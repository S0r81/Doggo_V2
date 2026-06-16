//
//  NutritionCheckIn.swift
//  Doggo_V2
//
//  One weekly rolling-average weigh-in. The book insists on weekly averages to
//  cut daily water noise (p.80). `targetWeightLost` is snapshotted so the
//  "stalled" status of any week is self-contained and never needs neighboring
//  rows to recompute.
//

import Foundation
import SwiftData

@Model
final class NutritionCheckIn {
    var id: UUID
    var date: Date
    /// 7-day rolling average bodyweight (kg) at this check-in.
    var rollingAverageWeight: Double
    /// Weight lost since the previous check-in (kg); negative = gained.
    var actualWeightLost: Double
    /// The loss this week was supposed to hit (previousWeight × targetRate).
    var targetWeightLost: Double
    /// True when this check-in triggered an automatic calorie cut.
    var wasMacroAdjustmentApplied: Bool

    var profile: NutritionProfile?

    init(
        date: Date = Date(),
        rollingAverageWeight: Double,
        actualWeightLost: Double,
        targetWeightLost: Double,
        wasMacroAdjustmentApplied: Bool = false
    ) {
        self.id = UUID()
        self.date = date
        self.rollingAverageWeight = rollingAverageWeight
        self.actualWeightLost = actualWeightLost
        self.targetWeightLost = targetWeightLost
        self.wasMacroAdjustmentApplied = wasMacroAdjustmentApplied
    }
}

extension NutritionCheckIn {
    /// A week stalled when actual loss < 50% of target (mirrors
    /// MacroCalculator.weekStalled, kept here so a stored row is self-describing).
    var stalled: Bool {
        MacroCalculator.weekStalled(actualLossKg: actualWeightLost, targetLossKg: targetWeightLost)
    }
}
