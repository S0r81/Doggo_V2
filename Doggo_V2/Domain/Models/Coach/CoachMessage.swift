//
//  CoachMessage.swift
//  Doggo_V2
//
//  One turn in a Coach chat thread, persisted so conversations survive relaunch
//  and the model can be given prior turns as context.
//
//  Standalone model: threads are grouped by a plain `threadID` UUID field rather
//  than a SwiftData relationship, so there are NO relationships to cascade and
//  zero orphan/dangling risk.
//

import Foundation
import SwiftData

@Model
final class CoachMessage {
    var id: UUID
    /// Backing string for `CoachRole`.
    var roleRaw: String
    var text: String
    var timestamp: Date
    /// Groups messages into a conversation thread (not a relationship).
    var threadID: UUID

    init(role: CoachRole, text: String, threadID: UUID, timestamp: Date = Date()) {
        self.id = UUID()
        self.roleRaw = role.rawValue
        self.text = text
        self.threadID = threadID
        self.timestamp = timestamp
    }

    var role: CoachRole {
        get { CoachRole(rawValue: roleRaw) ?? .assistant }
        set { roleRaw = newValue.rawValue }
    }
}

nonisolated enum CoachRole: String, Codable {
    case user
    case assistant
}
