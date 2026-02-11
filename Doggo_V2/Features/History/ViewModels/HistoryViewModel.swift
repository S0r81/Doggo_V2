//
//  HistoryViewModel.swift
//  Doggo_V2
//

import Foundation
import SwiftData
import Observation

@Observable
final class HistoryViewModel {
    private let workoutRepository: WorkoutRepositoryProtocol
    private let context: ModelContext
    
    var sessions: [WorkoutSession] = []
    var isLoading = false
    var error: Error?
    
    init(workoutRepository: WorkoutRepositoryProtocol, context: ModelContext) {
        self.workoutRepository = workoutRepository
        self.context = context
    }
    
    /// Loads completed workout sessions
    func loadHistory() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            sessions = try await workoutRepository.fetchCompletedSessions()
        } catch {
            self.error = error
            print("Error loading history: \(error)")
        }
    }
    
    /// Deletes a workout session
    func deleteSession(_ session: WorkoutSession) async {
        do {
            try await workoutRepository.delete(session)
            // Refresh the list
            await loadHistory()
        } catch {
            self.error = error
            print("Error deleting session: \(error)")
        }
    }
    
    /// Creates a manual workout entry
    func createManualEntry() async {
        let newSession = WorkoutSession(name: "Manual Log")
        newSession.startTime = Date()
        newSession.date = Date()
        newSession.isCompleted = true
        newSession.duration = 3600
        
        do {
            try await workoutRepository.save(newSession)
            await loadHistory()
        } catch {
            self.error = error
            print("Error creating manual entry: \(error)")
        }
    }
    
    /// Performs silent cleanup of ghost sessions (incomplete and old)
    func performSilentCleanup() async {
        do {
            let ghostSessions = try await workoutRepository.fetchGhostSessions()
            
            for session in ghostSessions {
                context.delete(session)
                print("👻 Silently deleted ghost session from: \(session.date)")
            }
            
            if !ghostSessions.isEmpty {
                try context.save()
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}
