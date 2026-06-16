//
//  WorkoutSession.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData

@Model
class WorkoutSession {
    var id: UUID
    var date: Date
    var name: String // e.g., "Pull Day"
    var duration: TimeInterval
    var isCompleted: Bool
    var startTime: Date?
    
    // NEW: Session notes for logging how you felt, injuries, etc.
    var notes: String?
    
    // Relationship: If you delete a session, delete its sets too
    @Relationship(deleteRule: .cascade) var sets: [WorkoutSet] = []
    
    init(name: String = "New Workout") {
        self.id = UUID()
        self.date = Date()
        self.name = name
        self.duration = 0
        self.isCompleted = false
        self.startTime = nil
        self.notes = nil
    }
}
