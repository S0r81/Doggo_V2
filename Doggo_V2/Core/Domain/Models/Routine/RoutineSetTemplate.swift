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
    // We could add targetWeight here too if you wanted percentage-based lifting later
    
    // Parent
    var routineItem: RoutineItem?
    
    init(orderIndex: Int, targetReps: Int = 10) {
        self.orderIndex = orderIndex
        self.targetReps = targetReps
    }
}

