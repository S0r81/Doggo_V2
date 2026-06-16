//
//  RoutineSetTemplate.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

@Model
class RoutineSetTemplate {
    var orderIndex: Int
    var targetReps: Int
    /// Upper bound of a rep range ("6-8" → targetReps 6, targetRepsUpper 8).
    /// nil = fixed rep target. Additive optional, so no SwiftData migration.
    var targetRepsUpper: Int? = nil
    /// Target working weight (in the user's logging unit). Set manually or by
    /// the progression engine. nil = no target yet (ghost values take over).
    var targetWeight: Double? = nil

    // Parent
    var routineItem: RoutineItem?

    init(orderIndex: Int, targetReps: Int = 10, targetRepsUpper: Int? = nil, targetWeight: Double? = nil) {
        self.orderIndex = orderIndex
        self.targetReps = targetReps
        // Guard against inverted ranges at the source.
        if let upper = targetRepsUpper, upper > targetReps {
            self.targetRepsUpper = upper
        }
        self.targetWeight = targetWeight
    }
}

extension RoutineSetTemplate {
    /// "8" or "6-8" — the display form of the rep target.
    var repRangeLabel: String {
        if let upper = targetRepsUpper, upper > targetReps {
            return "\(targetReps)-\(upper)"
        }
        return "\(targetReps)"
    }

    /// The bar a set must clear for the progression engine to call it a full
    /// success: the top of the range when one exists (double progression —
    /// add reps inside the range, add weight once the top is reached).
    var successReps: Int {
        targetRepsUpper ?? targetReps
    }
}

/// Parses freeform rep text from AI responses and imported plans.
/// "8" → (8, nil) · "6-8" / "6–8" / "6 to 8" → (6, 8) · "12+" → (12, nil) ·
/// "AMRAP" → (10, nil) fallback.
struct RepRange {
    let lower: Int
    let upper: Int?

    static func parse(_ text: String, fallback: Int = 10) -> RepRange {
        let numbers = text
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
            .compactMap { Int($0) }

        guard let first = numbers.first, first > 0 else {
            return RepRange(lower: fallback, upper: nil)
        }
        if numbers.count >= 2, numbers[1] > first {
            return RepRange(lower: first, upper: numbers[1])
        }
        return RepRange(lower: first, upper: nil)
    }
}
