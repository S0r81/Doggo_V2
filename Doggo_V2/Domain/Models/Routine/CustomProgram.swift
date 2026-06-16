//
//  CustomProgram.swift
//  Doggo_V2
//
//  A user-built program: an ordered bundle of their own routines with weekday
//  assignments, re-appliable to the weekly schedule at any time. Routines are
//  referenced by UUID string (resolved at use; missing ones are skipped) so
//  deleting a routine can never strand the program in a crashing state.
//

import Foundation
import SwiftData

@Model
class CustomProgram {
    var id: UUID
    var name: String
    var details: String
    var createdAt: Date

    /// Parallel arrays: entry i = routineIDs[i] scheduled on weekdays[i].
    var routineIDs: [String] = []
    var weekdays: [String] = []

    init(name: String, details: String = "") {
        self.id = UUID()
        self.name = name
        self.details = details
        self.createdAt = Date()
    }
}
