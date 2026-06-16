//
//  GenerateProgramUseCase.swift
//  Doggo_V2
//
//  Generates a full multi-day program via the selected AI provider and
//  materializes it as Routines + a CustomProgram under "Your Programs".
//
//  Two-phase by design: `generate` is pure (network + parse + sanitize, no
//  DB writes) so the UI can preview; `save` performs all SwiftData work.
//
//  Insertion runs on the MAIN context (ProgramInstaller pattern): the new
//  Exercise/Routine models are immediately linked into UI-visible
//  relationships, which is exactly the cross-context handoff that crashes
//  when models come from a @ModelActor's background context.
//

import Foundation
import SwiftData

@MainActor
final class GenerateProgramUseCase {

    struct SaveResult {
        let program: CustomProgram
        let routinesCreated: Int
        let exercisesCreated: Int
    }

    private let client: AIClientProtocol

    init(client: AIClientProtocol) {
        self.client = client
    }

    // MARK: - Phase 1: Generate (no DB writes)

    func generate(
        daysPerWeek: Int,
        focus: String,
        profile: UserProfile?,
        availableExercises: [Exercise]
    ) async throws -> AIGeneratedProgram {
        let prompt = GeminiPromptBuilder.buildProgramPrompt(
            profile: profile,
            daysPerWeek: daysPerWeek,
            focus: focus,
            availableExercises: availableExercises
        )
        let response = try await client.sendRequest(prompt: prompt)
        let program = try GeminiResponseParser.parseProgram(response)
        return Self.sanitized(program)
    }

    // MARK: - Phase 2: Save (main context)

    /// Creates routines + exercises for every day and bundles them into a
    /// CustomProgram. Exercises are matched case-insensitively, then by
    /// canonical token set ("Bench Press (Barbell)" == "Barbell Bench Press"),
    /// and only created when no equivalent exists.
    @discardableResult
    func save(_ program: AIGeneratedProgram, context: ModelContext) -> SaveResult {
        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        var byExactName: [String: Exercise] = [:]
        var byCanonicalKey: [String: Exercise] = [:]
        for exercise in allExercises {
            byExactName[exercise.name.lowercased()] = exercise
            byCanonicalKey[Self.canonicalKey(exercise.name)] = exercise
        }

        var exercisesCreated = 0

        func resolveExercise(_ plan: AIGeneratedProgram.ExercisePlan) -> Exercise {
            let cleanName = Self.sanitizeExerciseName(plan.name)
            if let exact = byExactName[cleanName.lowercased()] { return exact }
            if let fuzzy = byCanonicalKey[Self.canonicalKey(cleanName)] { return fuzzy }

            let newExercise = Exercise(
                name: cleanName,
                type: plan.isCardio ? "Cardio" : "Strength",
                muscleGroup: Self.normalizedMuscleGroup(plan.muscleGroup, isCardio: plan.isCardio),
                cardioType: plan.resolvedTracking.rawValue,
                isCustom: false
            )
            context.insert(newExercise)
            byExactName[cleanName.lowercased()] = newExercise
            byCanonicalKey[Self.canonicalKey(cleanName)] = newExercise
            exercisesCreated += 1
            return newExercise
        }

        // 1. Materialize each day as a Routine
        let programTag = "ai-program:\(UUID().uuidString)"
        let programName = program.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedProgramName = programName.isEmpty ? "AI Program" : programName
        var createdRoutines: [Routine] = []

        for day in program.days {
            // The draft is user-edited before saving — names can be blanked
            // out and whole days emptied via swipe-to-delete.
            let plans = day.exercises.filter { !Self.sanitizeExerciseName($0.name).isEmpty }
            guard !plans.isEmpty else { continue }

            let dayName = day.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let routine = Routine(
                name: dayName.isEmpty ? "Day \(createdRoutines.count + 1)" : dayName,
                note: "Part of \(resolvedProgramName)"
            )
            routine.sourceProgram = programTag
            context.insert(routine)

            for (index, plan) in plans.enumerated() {
                let exercise = resolveExercise(plan)
                let routineItem = RoutineItem(orderIndex: index, exercise: exercise)

                for setIndex in 0..<max(1, plan.sets) {
                    routineItem.templateSets.append(
                        RoutineSetTemplate(orderIndex: setIndex, targetReps: max(1, plan.reps))
                    )
                }

                routineItem.routine = routine
                context.insert(routineItem)
            }
            createdRoutines.append(routine)
        }

        // 2. Bundle into a CustomProgram ("Your Programs")
        let customProgram = CustomProgram(
            name: resolvedProgramName,
            details: program.description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        customProgram.routineIDs = createdRoutines.map { $0.id.uuidString }
        customProgram.weekdays = Self.defaultWeekdays(forDayCount: createdRoutines.count)
        context.insert(customProgram)

        context.saveLogging()
        return SaveResult(
            program: customProgram,
            routinesCreated: createdRoutines.count,
            exercisesCreated: exercisesCreated
        )
    }

    // MARK: - Sanitization

    /// Cleans every name in the parsed program so the preview shows exactly
    /// what would be saved.
    static func sanitized(_ program: AIGeneratedProgram) -> AIGeneratedProgram {
        var copy = program
        copy.name = copy.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.description = copy.description.trimmingCharacters(in: .whitespacesAndNewlines)
        for dayIndex in copy.days.indices {
            copy.days[dayIndex].name = copy.days[dayIndex].name
                .trimmingCharacters(in: .whitespacesAndNewlines)
            for planIndex in copy.days[dayIndex].exercises.indices {
                copy.days[dayIndex].exercises[planIndex].name =
                    sanitizeExerciseName(copy.days[dayIndex].exercises[planIndex].name)
            }
        }
        return copy
    }

    // The naming rules live in the nonisolated `ExerciseSanitizer` so the
    // background import actor can share them. These forwarders keep existing
    // call sites (this use case, RoutineImportView) unchanged.
    static func sanitizeExerciseName(_ raw: String) -> String {
        ExerciseSanitizer.sanitizeName(raw)
    }

    static func canonicalKey(_ name: String) -> String {
        ExerciseSanitizer.canonicalKey(name)
    }

    static func normalizedMuscleGroup(_ raw: String, isCardio: Bool) -> String {
        ExerciseSanitizer.normalizedMuscleGroup(raw, isCardio: isCardio)
    }

    static func defaultWeekdays(forDayCount count: Int) -> [String] {
        ExerciseSanitizer.defaultWeekdays(forDayCount: count)
    }
}
