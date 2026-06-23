//
//  ProgramUninstallCrashTests.swift
//  Doggo_V2Tests
//
//  Reproduce-first coverage for the Lift-tab launch crash.
//
//  Repro: install a program, work out one of its routines (which links each
//  WorkoutSet to a RoutineItem) and edit it, install another program, then
//  uninstall the first. `uninstall` does context.delete(routine), cascading
//  away its RoutineItems — but WorkoutSet.routineItem had no inverse / nullify
//  rule, so those references dangled. Rendering the Lift tab then faulted a
//  tombstoned RoutineItem ("backing data could no longer be found") and crashed.
//

import Testing
import Foundation
import SwiftData
@testable import Doggo_V2

@MainActor
struct ProgramUninstallCrashTests {

    /// The full object graph the Lift tab touches.
    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Routine.self, RoutineItem.self, RoutineSetTemplate.self,
                Exercise.self, WorkoutSession.self, WorkoutSet.self, UserProfile.self,
            configurations: config
        )
    }

    /// A one-day program. `shared` is an exercise name reused across programs,
    /// so we can prove a shared library Exercise is never deleted by uninstall.
    private func program(id: String, day: String, shared: String) -> ProgramDefinition {
        ProgramDefinition(
            id: id, name: "Prog \(id)", tagline: "", description: "",
            level: "Beginner", daysPerWeek: 2, goals: [],
            days: [
                ProgramDay(name: day, items: [
                    ProgramItem(shared, "Chest", sets: 3, reps: 8),
                    ProgramItem("\(id) Accessory", "Arms", sets: 3, reps: 12)
                ])
            ]
        )
    }

    private func routine(_ ctx: ModelContext, source: String) throws -> Routine {
        let d = FetchDescriptor<Routine>(predicate: #Predicate { $0.sourceProgram == source })
        return try #require(try ctx.fetch(d).first)
    }

    /// Exact sequence from the bug report.
    @Test func liftTabSurvivesUninstallingEditedWorkedOutProgram() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let profile = UserProfile(name: "T", age: 30, heightCM: 180, weightKG: 80,
                                  activityLevel: "Moderate", fitnessGoal: "Build Muscle",
                                  experienceLevel: "Beginner")
        ctx.insert(profile)

        let progA = program(id: "prog-a", day: "A Day", shared: "Bench Press (Barbell)")
        let progB = program(id: "prog-b", day: "B Day", shared: "Bench Press (Barbell)")

        // 1. Install program A.
        ProgramInstaller.install(progA, replaceSchedule: false, context: ctx)

        // 2. Work out A's routine + edit it. Linking each set to its RoutineItem
        //    mirrors ActiveWorkoutViewModel (`set.routineItem = item`).
        let routineA = try routine(ctx, source: "prog-a")
        let item = try #require(routineA.items.sorted { $0.orderIndex < $1.orderIndex }.first)
        item.templateSets.append(RoutineSetTemplate(orderIndex: 99, targetReps: 5)) // an edit

        let session = WorkoutSession(name: "A Day")
        session.isCompleted = true
        ctx.insert(session)
        let set = WorkoutSet(weight: 135, reps: 5, orderIndex: 0)
        set.exercise = item.exercise
        set.routineItem = item            // ← the reference that dangles on uninstall
        set.workoutSession = session
        ctx.insert(set)
        try ctx.save()

        // 3. Install another program (shares "Bench Press (Barbell)").
        ProgramInstaller.install(progB, replaceSchedule: false, context: ctx)

        // 4. Uninstall the edited, worked-out program.
        ProgramInstaller.uninstall(progA, context: ctx)
        try ctx.save()

        // 5. Load the Lift tab from a FRESH context (forces faulting from the
        //    store, exactly like a relaunch) — this is the crash site.
        let fresh = ModelContext(container)
        let completed = try fresh.fetch(FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.isCompleted == true }))

        // RoutineListContent.lastPerformedByRoutine — verbatim traversal.
        var lastPerformed: [UUID: Date] = [:]
        for session in completed {
            for s in session.sets {
                if let rid = s.routineItem?.routine?.id, lastPerformed[rid] == nil {
                    lastPerformed[rid] = session.date
                }
            }
        }

        // Lift tab also faults every routine's items + exercises (row muscle groups).
        let routines = try fresh.fetch(FetchDescriptor<Routine>())
        for r in routines { for it in r.items { _ = it.exercise?.muscleGroup } }

        // Invariants the fix must guarantee:
        // a) the worked-out set's link to the deleted RoutineItem is nullified.
        let freshSet = try #require(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(freshSet.routineItem == nil,
                "WorkoutSet.routineItem must nullify when its RoutineItem is deleted, not dangle.")
        // b) only program A's routines are gone; B's survive.
        #expect(routines.count == 1)
        #expect(routines.first?.sourceProgram == "prog-b")
        // c) the shared library Exercise survives the uninstall.
        let benches = try fresh.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == "Bench Press (Barbell)" }))
        #expect(benches.count == 1, "Shared exercise must not be deleted by uninstall.")
    }

    /// Uninstalling one program must not break another program that shares an
    /// exercise: the shared library Exercise survives and the surviving
    /// program's RoutineItem still resolves it.
    @Test func uninstallKeepsSharedExerciseUsableByOtherProgram() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let progA = program(id: "prog-a", day: "A Day", shared: "Deadlift (Barbell)")
        let progB = program(id: "prog-b", day: "B Day", shared: "Deadlift (Barbell)")
        ProgramInstaller.install(progA, replaceSchedule: false, context: ctx)
        ProgramInstaller.install(progB, replaceSchedule: false, context: ctx)
        try ctx.save()

        ProgramInstaller.uninstall(progA, context: ctx)
        try ctx.save()

        let fresh = ModelContext(container)
        let deadlifts = try fresh.fetch(FetchDescriptor<Exercise>(
            predicate: #Predicate { $0.name == "Deadlift (Barbell)" }))
        #expect(deadlifts.count == 1, "Shared exercise must survive the uninstall exactly once.")

        let survivor = try routine(fresh, source: "prog-b")
        let names = survivor.items.compactMap { $0.exercise?.name }
        #expect(names.contains("Deadlift (Barbell)"),
                "Surviving program's item must still resolve the shared exercise.")
    }

    /// The Lift list's own swipe-to-delete (RoutineListView calls
    /// modelContext.delete(routine) directly) must also nullify, not dangle,
    /// the worked-out set's link.
    @Test func directRoutineDeleteNullifiesWorkoutSetLink() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let routine = Routine(name: "Leg Day")
        ctx.insert(routine)
        let ex = Exercise(name: "Squat (Barbell)", muscleGroup: "Legs", isCustom: false)
        ctx.insert(ex)
        let item = RoutineItem(orderIndex: 0, exercise: ex)
        item.routine = routine
        ctx.insert(item)

        let session = WorkoutSession(name: "Leg Day")
        session.isCompleted = true
        ctx.insert(session)
        let set = WorkoutSet(weight: 225, reps: 5, orderIndex: 0)
        set.exercise = ex
        set.routineItem = item
        set.routineID = routine.id
        set.workoutSession = session
        ctx.insert(set)
        try ctx.save()

        ctx.delete(routine)   // verbatim RoutineListView swipe path
        try ctx.save()

        let fresh = ModelContext(container)
        let freshSet = try #require(try fresh.fetch(FetchDescriptor<WorkoutSet>()).first)
        #expect(freshSet.routineItem == nil, "Direct routine delete must nullify the set's RoutineItem link.")
        // The denormalized routineID survives (harmless UUID) and never faults.
        #expect(freshSet.routineID == routine.id)
    }

    /// A RoutineItem whose exercise was deleted (nil) must not crash the Lift
    /// tab's row rendering (muscle-group + last-performed traversals).
    @Test func liftTabLoadsWithOrphanedRoutineItem() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let routine = Routine(name: "Orphan Day")
        ctx.insert(routine)
        let ex = Exercise(name: "Temp Exercise", muscleGroup: "Arms", isCustom: true)
        ctx.insert(ex)
        let item = RoutineItem(orderIndex: 0, exercise: ex)
        item.routine = routine
        ctx.insert(item)
        try ctx.save()

        ctx.delete(ex)        // orphans the RoutineItem (exercise -> nil)
        try ctx.save()

        let fresh = ModelContext(container)
        let routines = try fresh.fetch(FetchDescriptor<Routine>())
        // RoutineRowView.muscleGroups-style traversal must tolerate nil exercise.
        var muscles: [String] = []
        for r in routines {
            for it in r.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
                if let e = it.exercise, !e.isDeleted { muscles.append(e.muscleGroup) }
            }
        }
        #expect(muscles.isEmpty, "Orphaned item contributes no muscle group, and does not crash.")
        #expect(routines.count == 1)
    }

    /// uninstall() prunes weekly-schedule slots — both its own and any stale
    /// slot pointing at a routine that no longer exists.
    @Test func uninstallPrunesStaleScheduleSlots() throws {
        let container = try makeContainer()
        let ctx = ModelContext(container)

        let profile = UserProfile(name: "T", age: 30, heightCM: 180, weightKG: 80,
                                  activityLevel: "Moderate", fitnessGoal: "Build Muscle",
                                  experienceLevel: "Beginner")
        // A stale slot pointing at a routine UUID that never existed.
        profile.weeklySchedule["Sunday"] = UUID().uuidString
        ctx.insert(profile)

        let progA = program(id: "prog-a", day: "A Day", shared: "Row (Barbell)")
        ProgramInstaller.install(progA, replaceSchedule: false, context: ctx)
        try ctx.save()
        #expect(profile.weeklySchedule["Monday"] != nil, "Install schedules its day.")

        ProgramInstaller.uninstall(progA, context: ctx)
        try ctx.save()

        let fresh = ModelContext(container)
        let p = try #require(try fresh.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(p.weeklySchedule["Monday"] == nil, "Uninstalled routine's slot is cleared.")
        #expect(p.weeklySchedule["Sunday"] == nil, "Pre-existing stale slot is also pruned.")
    }
}
