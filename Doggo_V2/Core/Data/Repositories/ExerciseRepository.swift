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

final class ExerciseRepository: ExerciseRepositoryProtocol {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Fetches all exercises sorted by name
    func fetchAll() async throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Fetches exercises by muscle group
    func fetchByMuscleGroup(_ group: String) async throws -> [Exercise] {
        let descriptor = FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.muscleGroup == group },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
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
        context.insert(exercise)
        try context.save()
    }
    
    /// Deletes an exercise
    func delete(_ exercise: Exercise) async throws {
        context.delete(exercise)
        try context.save()
    }
}
