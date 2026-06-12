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
    /// Target working weight (in the user's logging unit). Set manually or by
    /// the progression engine. nil = no target yet (ghost values take over).
    var targetWeight: Double? = nil

    // Parent
    var routineItem: RoutineItem?

    init(orderIndex: Int, targetReps: Int = 10, targetWeight: Double? = nil) {
        self.orderIndex = orderIndex
        self.targetReps = targetReps
        self.targetWeight = targetWeight
    }
}

