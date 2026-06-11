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
    @MainActor
    func loadHistory() async {
        isLoading = true
        defer { isLoading = false }

        // Fetch on the MAIN context — these sessions are edited in
        // WorkoutDetailView, and models from the repository actor's background
        // context crash when mutated or linked from the main context.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == true },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            sessions = try context.fetch(descriptor)
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
    @MainActor
    func createManualEntry() async {
        let newSession = WorkoutSession(name: "Manual Log")
        newSession.startTime = Date()
        newSession.date = Date()
        newSession.isCompleted = true
        newSession.duration = 3600

        do {
            context.insert(newSession)
            try context.save()
            await loadHistory()
        } catch {
            self.error = error
            print("Error creating manual entry: \(error)")
        }
    }

    /// Performs silent cleanup of ghost sessions (incomplete and old)
    @MainActor
    func performSilentCleanup() async {
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> {
                $0.isCompleted == false && $0.date < oneDayAgo
            }
        )

        do {
            let ghostSessions = try context.fetch(descriptor)
            var deletedAny = false

            for session in ghostSessions {
                // A "ghost" with completed sets is a real workout the user can
                // still resume (e.g. started yesterday evening) — deleting it
                // out from under the active workout tab crashes the app.
                guard !session.sets.contains(where: { $0.isCompleted }) else { continue }

                context.delete(session)
                deletedAny = true
                print("👻 Silently deleted ghost session from: \(session.date)")
            }

            if deletedAny {
                try context.save()
            }
        } catch {
            print("Cleanup error: \(error)")
        }
    }
}
