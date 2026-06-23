//
//  ProgramInstaller.swift
//  Doggo_V2
//
//  Materializes a ProgramDefinition into real Routines, RoutineItems, and
//  set templates, then places the days on the weekly schedule.
//

import Foundation
import SwiftData

@MainActor
enum ProgramInstaller {

    struct Result {
        let routinesCreated: Int
        let daysScheduled: Int
    }

    /// True if any routine from this program already exists.
    static func isInstalled(_ program: ProgramDefinition, context: ModelContext) -> Bool {
        let programID = program.id
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.sourceProgram == programID }
        )
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    /// Creates the program's routines and schedules them.
    /// - Parameter replaceSchedule: when false, only empty weekdays are filled.
    @discardableResult
    static func install(
        _ program: ProgramDefinition,
        replaceSchedule: Bool,
        context: ModelContext
    ) -> Result {
        // Exercise lookup (find-or-create, case-insensitive) — same pattern
        // as the CSV importer.
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var exercisesByName: [String: Exercise] = [:]
        for exercise in allExercises {
            exercisesByName[exercise.name.lowercased()] = exercise
        }

        func resolveExercise(_ item: ProgramItem) -> Exercise {
            let key = item.exercise.lowercased()
            if let existing = exercisesByName[key] { return existing }
            let newExercise = Exercise(
                name: item.exercise,
                type: "Strength",
                muscleGroup: item.muscleGroup,
                isCustom: false
            )
            context.insert(newExercise)
            exercisesByName[key] = newExercise
            return newExercise
        }

        // 1. Build the routines
        var createdRoutines: [Routine] = []

        for day in program.days {
            let routine = Routine(name: day.name, note: "Part of \(program.name)")
            routine.sourceProgram = program.id
            context.insert(routine)

            var supersetIDs: [Int: UUID] = [:]

            for (index, item) in day.items.enumerated() {
                let exercise = resolveExercise(item)
                let routineItem = RoutineItem(orderIndex: index, exercise: exercise)

                if let group = item.supersetGroup {
                    if supersetIDs[group] == nil { supersetIDs[group] = UUID() }
                    routineItem.supersetID = supersetIDs[group]
                }

                for setIndex in 0..<item.sets {
                    routineItem.templateSets.append(
                        RoutineSetTemplate(orderIndex: setIndex, targetReps: item.reps)
                    )
                }

                routineItem.routine = routine
                context.insert(routineItem)
            }
            createdRoutines.append(routine)
        }

        // 2. Schedule the days
        var daysScheduled = 0
        if let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            if replaceSchedule {
                profile.weeklySchedule.removeAll()
            }
            for (routine, weekday) in zip(createdRoutines, program.defaultWeekdays) {
                // Respect existing plans unless replacing
                if replaceSchedule || profile.weeklySchedule[weekday] == nil {
                    profile.weeklySchedule[weekday] = routine.id.uuidString
                    daysScheduled += 1
                }
            }
        }

        context.saveLogging()
        return Result(routinesCreated: createdRoutines.count, daysScheduled: daysScheduled)
    }

    /// Removes every routine this program installed and clears their slots on
    /// the weekly schedule. Workout history (sessions/sets) is untouched.
    /// Returns the number of routines removed.
    @discardableResult
    static func uninstall(_ program: ProgramDefinition, context: ModelContext) -> Int {
        let programID = program.id
        let descriptor = FetchDescriptor<Routine>(
            predicate: #Predicate<Routine> { $0.sourceProgram == programID }
        )
        guard let routines = try? context.fetch(descriptor), !routines.isEmpty else {
            // Nothing from this program, but still sweep any stale schedule slots.
            pruneSchedule(context: context)
            return 0
        }

        // Delete this program's routines. The cascade removes their RoutineItems
        // and RoutineSetTemplates; RoutineItem.workoutSets is .nullify, so logged
        // workout history is detached (WorkoutSet.routineItem -> nil), never
        // deleted and never left dangling. Shared/library Exercises are untouched
        // (RoutineItem.exercise defaults to .nullify).
        for routine in routines {
            context.delete(routine)
        }
        context.saveLogging()

        // Drop every weekly-schedule slot that no longer resolves to a surviving
        // routine — the ones we just removed plus any stale slots left behind by
        // earlier edits or deletions — then persist, so the graph can't be left
        // half-cleaned.
        pruneSchedule(context: context)

        return routines.count
    }

    /// Removes weekly-schedule entries whose routine UUID no longer maps to an
    /// existing Routine. Idempotent and safe to call after any routine removal.
    private static func pruneSchedule(context: ModelContext) {
        guard let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first else { return }
        let liveIDs = Set(((try? context.fetch(FetchDescriptor<Routine>())) ?? []).map { $0.id.uuidString })
        let staleDays = profile.weeklySchedule.filter { !liveIDs.contains($0.value) }.map(\.key)
        guard !staleDays.isEmpty else { return }
        for day in staleDays { profile.weeklySchedule.removeValue(forKey: day) }
        context.saveLogging()
    }
}
