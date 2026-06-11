//
//  ExerciseRepository.swift
//  Doggo_V2
//

import Foundation
import SwiftData

protocol ExerciseRepositoryProtocol {
    func fetchAll() async throws -> [Exercise]
    func fetchByMuscleGroup(_ group: String) async throws -> [Exercise]
    func searchByName(_ query: String) async throws -> [Exercise]
    func save(_ exercise: Exercise) async throws
    func delete(_ exercise: Exercise) async throws
}

@ModelActor
actor ExerciseRepository: ExerciseRepositoryProtocol {
    // The @ModelActor macro automatically generates the initializer taking a ModelContainer,
    // and provides a thread-safe `modelContext`.
    
    /// Fetches all exercises sorted by name
    func fetchAll() async throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetches exercises by muscle group
    func fetchByMuscleGroup(_ group: String) async throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.muscleGroup == group },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Searches exercises by name (case-insensitive)
    func searchByName(_ query: String) async throws -> [Exercise] {
        // Note: SwiftData doesn't support localizedCaseInsensitiveContains in predicates
        // So we fetch all and filter in memory
        let all = try await fetchAll()
        return all.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    /// Saves an exercise
    func save(_ exercise: Exercise) async throws {
        modelContext.insert(exercise)
        try modelContext.save()
    }
    
    /// Deletes an exercise
    func delete(_ exercise: Exercise) async throws {
        // Safely resolve the model into this actor's context before deleting
        // This prevents cross-thread crashes!
        let id = exercise.persistentModelID
        if let resolvedExercise = self[id, as: Exercise.self] {
            modelContext.delete(resolvedExercise)
            try modelContext.save()
        }
    }
}
