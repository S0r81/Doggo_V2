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

final class RoutineRepository: RoutineRepositoryProtocol {
    private let context: ModelContext
    
    init(context: ModelContext) {
        self.context = context
    }
    
    /// Fetches all routines
    func fetchAll() async throws -> [Routine] {
        let descriptor = FetchDescriptor<Routine>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }
    
    /// Saves a routine
    func save(_ routine: Routine) async throws {
        context.insert(routine)
        try context.save()
    }
    
    /// Deletes a routine
    func delete(_ routine: Routine) async throws {
        context.delete(routine)
        try context.save()
    }
}
