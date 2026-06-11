//
//  Exercise.swift
//  Doggo_V2
//

import SwiftData
import Foundation

@Model
class Exercise {
    var id: UUID
    var name: String
    var type: String // "Strength" or "Cardio"
    var muscleGroup: String
    var cardioType: String
    
    // MARK: - NEW PROPERTIES
    var isFavorite: Bool = false
    var isCustom: Bool = false // If true, user can delete it.
    
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet] = []
    
    // Adding inverse relationships so SwiftData knows to nullify the reference in RoutineItem
    // if this exercise is ever deleted. This prevents the "backing data could no longer be found" crash.
    @Relationship(inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []
    
    init(
        name: String,
        type: String = "Strength",
        muscleGroup: String = "Other",
        cardioType: String = "Distance",
        isCustom: Bool = true // Default to true for new user-created exercises
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.muscleGroup = muscleGroup
        self.cardioType = cardioType
        self.isCustom = isCustom
        self.isFavorite = false
    }
}
