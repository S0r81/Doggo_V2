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

@ModelActor
actor WorkoutRepository: WorkoutRepositoryProtocol {
    
    /// Fetches all incomplete (active) workout sessions
    func fetchActiveSessions() async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches all completed workout sessions
    func fetchCompletedSessions() async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches recent completed sessions (for dashboard)
    func fetchRecentSessions(limit: Int) async throws -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        var sessions = try modelContext.fetch(descriptor)
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
        return try modelContext.fetch(descriptor)
    }
    
    /// Saves a workout session
    func save(_ session: WorkoutSession) async throws {
        modelContext.insert(session)
        try modelContext.save()
    }
    
    /// Deletes a workout session
    func delete(_ session: WorkoutSession) async throws {
        let id = session.persistentModelID
        if let resolved = self[id, as: WorkoutSession.self] {
            modelContext.delete(resolved)
            try modelContext.save()
        }
    }
}
