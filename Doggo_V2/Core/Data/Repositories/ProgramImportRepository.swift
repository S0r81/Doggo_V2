//
//  ProgramImportRepository.swift
//  Doggo_V2
//
//  Materializes a shared-program snapshot into real Routines, RoutineItems,
//  exercises, and a CustomProgram — entirely on this @ModelActor's background
//  context. Because the whole object graph is built and saved here and only a
//  Sendable summary is returned, no background-context model ever crosses into
//  a main-context relationship (the cross-context handoff that crashes). The
//  UI sees the result through its @Query, which observes the shared store.
//
//  The decoded SharedProgram is untrusted input (anyone can craft a link), so
//  every exercise name flows through the same ExerciseSanitizer rules as the
//  AI import path: sanitize → exact match → canonical token-set match → create.
//

import Foundation
import SwiftData

struct ProgramImportSummary: Sendable {
    let programName: String
    let routinesCreated: Int
    let exercisesCreated: Int
}

protocol ProgramImportRepositoryProtocol {
    @discardableResult
    func importShared(_ program: SharedProgram) async throws -> ProgramImportSummary
}

@ModelActor
actor ProgramImportRepository: ProgramImportRepositoryProtocol {

    @discardableResult
    func importShared(_ program: SharedProgram) async throws -> ProgramImportSummary {
        // Exercise lookup on THIS context (exact name, then canonical token set).
        let allExercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        var byExactName: [String: Exercise] = [:]
        var byCanonicalKey: [String: Exercise] = [:]
        for exercise in allExercises {
            byExactName[exercise.name.lowercased()] = exercise
            byCanonicalKey[ExerciseSanitizer.canonicalKey(exercise.name)] = exercise
        }

        var exercisesCreated = 0

        func resolveExercise(_ item: SharedProgram.Item) -> Exercise {
            let cleanName = ExerciseSanitizer.sanitizeName(item.name)
            if let exact = byExactName[cleanName.lowercased()] { return exact }
            if let fuzzy = byCanonicalKey[ExerciseSanitizer.canonicalKey(cleanName)] { return fuzzy }

            let isCardio = item.type.caseInsensitiveCompare("Cardio") == .orderedSame
            let newExercise = Exercise(
                name: cleanName,
                type: isCardio ? "Cardio" : "Strength",
                muscleGroup: ExerciseSanitizer.normalizedMuscleGroup(item.muscleGroup, isCardio: isCardio),
                cardioType: CardioTrackingType.from(item.cardioType).rawValue,
                isCustom: false
            )
            modelContext.insert(newExercise)
            byExactName[cleanName.lowercased()] = newExercise
            byCanonicalKey[ExerciseSanitizer.canonicalKey(cleanName)] = newExercise
            exercisesCreated += 1
            return newExercise
        }

        // 1. Rebuild each day as a Routine.
        let programTag = "shared-program:\(UUID().uuidString)"
        let trimmedName = program.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty ? "Shared Program" : trimmedName

        var createdRoutines: [Routine] = []
        var weekdays: [String] = []

        for day in program.days {
            let items = day.items.filter { !ExerciseSanitizer.sanitizeName($0.name).isEmpty }
            guard !items.isEmpty else { continue }

            let dayName = day.routineName.trimmingCharacters(in: .whitespacesAndNewlines)
            let routine = Routine(
                name: dayName.isEmpty ? "Day \(createdRoutines.count + 1)" : dayName,
                note: day.note
            )
            routine.sourceProgram = programTag
            modelContext.insert(routine)

            var supersetIDs: [Int: UUID] = [:]

            for (index, item) in items.enumerated() {
                let exercise = resolveExercise(item)
                let routineItem = RoutineItem(orderIndex: index, exercise: exercise, note: item.note)

                if let group = item.superset {
                    if supersetIDs[group] == nil { supersetIDs[group] = UUID() }
                    routineItem.supersetID = supersetIDs[group]
                }

                // A day with no set templates still gets one sane default set.
                let templates = item.sets.isEmpty
                    ? [SharedProgram.SetTemplate(reps: 10, repsUpper: nil, weight: nil)]
                    : item.sets
                for (setIndex, set) in templates.enumerated() {
                    let template = RoutineSetTemplate(
                        orderIndex: setIndex,
                        targetReps: max(1, set.reps),
                        targetRepsUpper: set.repsUpper,
                        targetWeight: set.weight
                    )
                    template.routineItem = routineItem
                    routineItem.templateSets.append(template)
                }

                routineItem.routine = routine
                modelContext.insert(routineItem)
            }

            createdRoutines.append(routine)
            weekdays.append(day.weekday ?? "")
        }

        // 2. Bundle into a CustomProgram under "Your Programs".
        let customProgram = CustomProgram(
            name: resolvedName,
            details: program.details.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        customProgram.routineIDs = createdRoutines.map { $0.id.uuidString }
        // Keep the sender's weekday layout only if it's complete; otherwise
        // fall back to sensible defaults so the schedule never gets blank keys.
        let hasAllWeekdays = weekdays.count == createdRoutines.count && !weekdays.contains(where: { $0.isEmpty })
        customProgram.weekdays = hasAllWeekdays
            ? weekdays
            : ExerciseSanitizer.defaultWeekdays(forDayCount: createdRoutines.count)
        modelContext.insert(customProgram)

        try modelContext.save()

        return ProgramImportSummary(
            programName: resolvedName,
            routinesCreated: createdRoutines.count,
            exercisesCreated: exercisesCreated
        )
    }
}
