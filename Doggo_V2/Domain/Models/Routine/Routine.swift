//
//  Routine.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

@Model
class Routine {
    var id: UUID
    var name: String
    var note: String
    /// Set when this routine was installed from a bundled program.
    var sourceProgram: String? = nil
    
    // Relationship: A routine has many ordered items
    // If we delete the routine, delete the items (but NOT the exercises themselves)
    @Relationship(deleteRule: .cascade, inverse: \RoutineItem.routine)
    var items: [RoutineItem] = []
    
    init(name: String, note: String = "") {
        self.id = UUID()
        self.name = name
        self.note = note
    }
}

// Drag & drop transfers the routine's UUID string directly (see
// WeeklyPlannerView: `.draggable(routine.id.uuidString)` /
// `.dropDestination(for: String.self)`), so the @Model itself never needs a
// Transferable/Sendable conformance — which a PersistentModel can't satisfy
// under Swift 6.

