import Foundation
import SwiftData

@Model
class RoutineItem {
    var orderIndex: Int
    @Relationship var exercise: Exercise?
    var routine: Routine?
    var note: String?
    
    // NEW: Links items together. If multiple items share this ID, they are a Superset.
    var supersetID: UUID?

    // Progression engine state: consecutive sessions where every target was
    // hit (or missed). Reset when a target changes.
    var successStreak: Int = 0
    var failStreak: Int = 0
    
    @Relationship(deleteRule: .cascade, inverse: \RoutineSetTemplate.routineItem)
    var templateSets: [RoutineSetTemplate] = []
    
    init(orderIndex: Int, exercise: Exercise, note: String? = nil, supersetID: UUID? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.note = note
        self.supersetID = supersetID
    }
}

