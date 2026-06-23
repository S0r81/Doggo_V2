//
//  WorkoutSet.swift
//  Doggo_V2
//

import SwiftData
import Foundation

@Model
class WorkoutSet {
    var id: UUID
    var weight: Double
    var reps: Int
    var orderIndex: Int
    var isCompleted: Bool
    
    // Unit for this specific set (e.g., "lbs", "kg", "mi", "km", "steps")
    var unit: String = "lbs"
    
    // Cardio session metrics. A cardio exercise owns exactly ONE WorkoutSet
    // per workout (the "session block") — enforced in ActiveWorkoutViewModel.
    var distance: Double?   // in `unit` (mi/km)
    var duration: Double?   // minutes
    var steps: Int?
    
    @Relationship(inverse: \WorkoutSession.sets)
    var workoutSession: WorkoutSession?
    
    @Relationship(inverse: \Exercise.sets)
    var exercise: Exercise?
    
    // Inverse declared on RoutineItem.workoutSets (deleteRule .nullify), so
    // deleting a RoutineItem detaches this link instead of leaving it dangling.
    var routineItem: RoutineItem?

    // Denormalized id of the routine this set was performed under. The Lift
    // tab's "last performed" lookup reads this instead of faulting
    // routineItem?.routine — so the tab stays safe even against legacy sets
    // whose RoutineItem was deleted before the inverse rule existed. nil for
    // sets logged before this field was added (they simply don't contribute a
    // "last performed" date — a graceful degrade, never a crash).
    var routineID: UUID?

    init(weight: Double, reps: Int, orderIndex: Int, unit: String = "lbs") {
        self.id = UUID()
        self.weight = weight
        self.reps = reps
        self.orderIndex = orderIndex
        self.isCompleted = false
        self.unit = unit
        self.steps = 0
        self.distance = 0.0
        self.duration = 0.0
    }
    
    // MARK: - Helper Logic
    /// True for count-based cardio (steps, floors, laps) — the count value is
    /// stored in `steps` for all three; `unit` carries which kind it is.
    var isStepsBased: Bool {
        ["steps", "floors", "laps"].contains(unit.lowercased())
            || (exercise?.name.localizedCaseInsensitiveContains("Stair") ?? false)
    }
}
