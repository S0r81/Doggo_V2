//
//  Routine.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI // Required for Transferable

@Model
class Routine {
    var id: UUID
    var name: String
    var note: String
    
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

// MARK: - Drag & Drop Support
extension Routine: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        // We export the Routine's ID as a String so the Planner knows which one was dropped
        ProxyRepresentation(exporting: \.id.uuidString)
    }
}

