//
//  RoutineRepository.swift
//  Doggo_V2
//

import Foundation
import SwiftData

protocol RoutineRepositoryProtocol {
    func fetchAll() async throws -> [Routine]
    func save(_ routine: Routine) async throws
    func delete(_ routine: Routine) async throws
}

@ModelActor
actor RoutineRepository: RoutineRepositoryProtocol {
    
    /// Fetches all routines
    func fetchAll() async throws -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Saves a routine
    func save(_ routine: Routine) async throws {
        modelContext.insert(routine)
        try modelContext.save()
    }
    
    /// Deletes a routine
    func delete(_ routine: Routine) async throws {
        let id = routine.persistentModelID
        if let resolved = self[id, as: Routine.self] {
            modelContext.delete(resolved)
            try modelContext.save()
        }
    }
}
