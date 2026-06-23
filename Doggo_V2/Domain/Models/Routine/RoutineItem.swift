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

    // Workout-history sets logged against this item. deleteRule .nullify (never
    // cascade): deleting a routine and its items must NOT delete workout
    // history — it only detaches the link (WorkoutSet.routineItem -> nil) so no
    // set is left pointing at a deleted RoutineItem. This inverse is the fix for
    // the Lift-tab "backing data could no longer be found" crash that occurred
    // when a worked-out routine was uninstalled/deleted.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSet.routineItem)
    var workoutSets: [WorkoutSet] = []

    init(orderIndex: Int, exercise: Exercise, note: String? = nil, supersetID: UUID? = nil) {
        self.orderIndex = orderIndex
        self.exercise = exercise
        self.note = note
        self.supersetID = supersetID
    }
}

