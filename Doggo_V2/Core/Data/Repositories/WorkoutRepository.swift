//
//  WorkoutRepository.swift
//  Doggo_V2
//

import Foundation
import SwiftData

protocol WorkoutRepositoryProtocol {
    func fetchActiveSessions() async throws -> [WorkoutSession]
    func fetchCompletedSessions() async throws -> [WorkoutSession]
    func fetchRecentSessions(limit: Int) async throws -> [WorkoutSession]
    func fetchGhostSessions() async throws -> [WorkoutSession]
    func save(_ session: WorkoutSession) async throws
    func delete(_ session: WorkoutSession) async throws
}

final class WorkoutRepository: WorkoutRepositoryProtocol {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Fetches all incomplete (active) workout sessions
    func fetchActiveSessions() async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetches all completed workout sessions
    func fetchCompletedSessions() async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetches recent completed sessions (for dashboard)
    func fetchRecentSessions(limit: Int) async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var sessions = try context.fetch(descriptor)
        if sessions.count > limit {
            sessions = Array(sessions.prefix(limit))
        }
        return sessions
    }
    
    /// Fetches "ghost" sessions (incomplete and older than 24 hours)
    func fetchGhostSessions() async throws -> [WorkoutSession] {
        let oneDayAgo = Date().addingTimeInterval(-86400) // 24 hours ago
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false && $0.date < oneDayAgo
            }
        )
        return try context.fetch(descriptor)
    }
    
    /// Saves a workout session
    func save(_ session: WorkoutSession) async throws {
        context.insert(session)
        try context.save()
    }
    
    /// Deletes a workout session
    func delete(_ session: WorkoutSession) async throws {
        context.delete(session)
        try context.save()
    }
}
