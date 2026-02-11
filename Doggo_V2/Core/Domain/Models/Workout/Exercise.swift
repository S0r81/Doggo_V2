//
//  Exercise.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftData
import Foundation

@Model
class Exercise {
    var id: UUID
    var name: String
    var type: String // "Strength" or "Cardio"
    var muscleGroup: String
    
    // NEW: Defines what metrics to track for cardio
    // Options: "Distance" (default), "Steps", "Time"
    var cardioType: String
    
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet] = []
    
    init(
        name: String,
        type: String = "Strength",
        muscleGroup: String = "Other",
        cardioType: String = "Distance"
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.muscleGroup = muscleGroup
        self.cardioType = cardioType
    }
}
