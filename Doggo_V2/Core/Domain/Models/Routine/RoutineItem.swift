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
    
    @Relationship(deleteRule: .cascade, inverse: \RoutineSetTemplate.routineItem)
    var templateSets: [RoutineSetTemplate] = []
    
    init(orderIndex: Int, exercise: Exercise, note: String? = nil, supersetID: UUID? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.note = note
        self.supersetID = supersetID
    }
}

