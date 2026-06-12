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
    func importSessions(_ imported: [CSVImporter.ImportedSession]) async throws -> ImportResult
}

struct ImportResult: Sendable {
    let importedSessions: Int
    let skippedDuplicates: Int
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

    // MARK: - CSV Import (background context)

    /// Inserts parsed CSV sessions entirely on this actor's background
    /// context — a multi-year history import never touches the main thread.
    /// Dedup rule: a (day, exercise name) pair that already exists in the
    /// store is skipped; sessions whose every exercise is a duplicate are
    /// skipped wholesale.
    func importSessions(_ imported: [CSVImporter.ImportedSession]) async throws -> ImportResult {
        // 1. Build the dedup index from existing data: "dayTimestamp|exercise"
        let existingSessions = try modelContext.fetch(FetchDescriptor<WorkoutSession>())
        let calendar = Calendar.current

        var existingKeys = Set<String>()
        for session in existingSessions {
            let day = calendar.startOfDay(for: session.date).timeIntervalSince1970
            for set in session.sets {
                if let name = set.exercise?.name.lowercased() {
                    existingKeys.insert("\(day)|\(name)")
                }
            }
        }

        // 2. Exercise lookup (find-or-create by case-insensitive name)
        let allExercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        var exercisesByName: [String: Exercise] = [:]
        for exercise in allExercises {
            exercisesByName[exercise.name.lowercased()] = exercise
        }

        func resolveExercise(_ data: CSVImporter.ImportedExercise) -> Exercise {
            let key = data.name.lowercased()
            if let existing = exercisesByName[key] { return existing }

            let resolvedType = data.type.isEmpty ? "Strength" : data.type
            // Reconstruct the tracking type from the CSV's Unit column;
            // unknown/legacy values fall back safely (never crashes).
            let tracking = CardioTrackingType.inferred(
                fromUnit: data.sets.first?.unit ?? "",
                hasDistance: data.sets.contains { ($0.distance ?? 0) > 0 }
            )

            let newExercise = Exercise(
                name: data.name,
                type: resolvedType,
                muscleGroup: data.muscleGroup.isEmpty ? "Other" : data.muscleGroup,
                cardioType: tracking.rawValue
            )
            modelContext.insert(newExercise)
            exercisesByName[key] = newExercise
            return newExercise
        }

        // 3. Insert, skipping duplicates
        var importedCount = 0
        var skippedCount = 0

        for sessionData in imported {
            let day = calendar.startOfDay(for: sessionData.date).timeIntervalSince1970
            let newExercises = sessionData.exercises.filter { exercise in
                !existingKeys.contains("\(day)|\(exercise.name.lowercased())")
            }

            guard !newExercises.isEmpty else {
                skippedCount += 1
                continue
            }

            let newSession = WorkoutSession(name: sessionData.name)
            newSession.date = sessionData.date
            newSession.duration = sessionData.duration
            newSession.isCompleted = true
            modelContext.insert(newSession)

            var orderIndex = 0
            for exerciseData in newExercises {
                let exercise = resolveExercise(exerciseData)
                existingKeys.insert("\(day)|\(exerciseData.name.lowercased())")

                if exercise.isCardio || exerciseData.type == "Cardio" {
                    // Cardio invariant: ONE session block per exercise per
                    // workout. Old exports (and third-party CSVs) may carry
                    // multiple cardio rows — consolidate them by summing.
                    let totalDuration = exerciseData.sets.compactMap(\.time).reduce(0, +)
                    let totalDistance = exerciseData.sets.compactMap(\.distance).reduce(0, +)
                    let totalSteps = exerciseData.sets.compactMap(\.steps).reduce(0, +)

                    let csvUnit = exerciseData.sets.first?.unit ?? ""
                    let sessionBlock = WorkoutSet(
                        weight: 0,
                        reps: 0,
                        orderIndex: orderIndex,
                        unit: csvUnit.isEmpty ? exercise.defaultUnit(isMetric: false) : csvUnit
                    )
                    if totalDistance > 0 { sessionBlock.distance = totalDistance }
                    if totalDuration > 0 { sessionBlock.duration = totalDuration }
                    if totalSteps > 0 { sessionBlock.steps = totalSteps }
                    sessionBlock.isCompleted = true
                    sessionBlock.exercise = exercise
                    sessionBlock.workoutSession = newSession
                    modelContext.insert(sessionBlock)
                    orderIndex += 1
                } else {
                    for setData in exerciseData.sets {
                        let newSet = WorkoutSet(
                            weight: setData.weight,
                            reps: Int(setData.reps),
                            orderIndex: orderIndex,
                            unit: setData.unit
                        )
                        if let distance = setData.distance { newSet.distance = distance }
                        if let time = setData.time { newSet.duration = time }
                        if let steps = setData.steps { newSet.steps = steps }
                        newSet.isCompleted = true
                        newSet.exercise = exercise
                        newSet.workoutSession = newSession
                        modelContext.insert(newSet)
                        orderIndex += 1
                    }
                }
            }
            importedCount += 1
        }

        try modelContext.save()
        return ImportResult(importedSessions: importedCount, skippedDuplicates: skippedCount)
    }
}
