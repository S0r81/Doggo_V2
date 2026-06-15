//
//  ActiveWorkoutViewModel.swift
//  Doggo_V2
//

import Foundation
import SwiftData
import SwiftUI
import UIKit
import ActivityKit

@Observable
class ActiveWorkoutViewModel {
    private let workoutRepository: WorkoutRepositoryProtocol
    
    var currentSession: WorkoutSession?
    
    // Main Workout Duration Timer
    var elapsedSeconds: Int = 0
    var isTimerRunning = false
    private var workoutTimer: Timer?
    
    var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init(workoutRepository: WorkoutRepositoryProtocol, context: ModelContext) {
        self.workoutRepository = workoutRepository
        self.modelContext = context
    }
    
    // MARK: - Start & Resume
    
    @MainActor
    func checkForActiveSession() async {
        guard let context = modelContext else { return }

        // Fetch on the MAIN context. The repository is a @ModelActor with its own
        // background context — resuming one of its instances and then linking
        // main-context sets to it crashes with a cross-context relationship error.
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate<WorkoutSession> { $0.isCompleted == false },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )

        do {
            let activeSessions = try context.fetch(descriptor)
            if let existingSession = activeSessions.first {
                if let current = currentSession, current.id == existingSession.id { return }
                resumeSession(existingSession)
            }
        } catch {
            print("Error checking for active session: \(error)")
        }
    }
    
    func startNewWorkout() {
        guard let context = modelContext else { return }
        let newSession = WorkoutSession(name: "Freestyle Workout")
        newSession.startTime = Date()
        context.insert(newSession)
        self.currentSession = newSession
        self.startWorkoutTimer()
    }
    
    func startWorkout(from routine: Routine) {
        guard let context = modelContext else { return }
        let newSession = WorkoutSession(name: routine.name)
        newSession.startTime = Date()
        context.insert(newSession)
        
        let sortedItems = routine.items.sorted { $0.orderIndex < $1.orderIndex }
        var globalOrderIndex = 0
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        
        for item in sortedItems {
            if let exercise = item.exercise {
                let sortedTemplates = item.templateSets.sorted { $0.orderIndex < $1.orderIndex }

                // Unit follows the exercise's tracking type (mi/km, steps,
                // floors, laps, min) — single source of truth on Exercise.
                let unitForThisExercise = exercise.defaultUnit(isMetric: isMetric)
                
                if exercise.isCardio {
                    // Cardio: exactly one session block, regardless of how
                    // many template "sets" the routine carries.
                    globalOrderIndex += 1
                    let set = WorkoutSet(weight: 0, reps: 0, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                    set.exercise = exercise
                    set.workoutSession = newSession
                    set.routineItem = item
                    context.insert(set)
                } else if sortedTemplates.isEmpty {
                    globalOrderIndex += 1
                    let set = WorkoutSet(weight: 0, reps: 0, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                    set.exercise = exercise
                    set.workoutSession = newSession
                    set.routineItem = item
                    context.insert(set)
                } else {
                    for template in sortedTemplates {
                        globalOrderIndex += 1
                        let realSet = WorkoutSet(weight: 0, reps: template.targetReps, orderIndex: globalOrderIndex, unit: unitForThisExercise)
                        realSet.exercise = exercise
                        realSet.workoutSession = newSession
                        realSet.routineItem = item
                        context.insert(realSet)
                    }
                }
            }
        }
        
        self.currentSession = newSession
        self.startWorkoutTimer()
    }
    
    func deleteExercise(_ exercise: Exercise) {
            guard let session = currentSession, let context = modelContext else { return }
            
            // Find all sets for this exercise in the current session
            let setsToDelete = session.sets.filter { $0.exercise?.id == exercise.id }
            
            // Delete them
            for set in setsToDelete {
                context.delete(set)
            }
            
            // Optional: Save immediately to trigger UI refresh
            context.saveLogging()
        }
    
    // MARK: - Set Management
    
    func addSet(to exercise: Exercise, weight: Double, reps: Int) {
        guard let session = currentSession, let context = modelContext else { return }

        // Cardio is one continuous session, not a list of sets — if a session
        // block already exists for this exercise, adding again is a no-op.
        if exercise.isCardio,
           session.sets.contains(where: { $0.exercise?.id == exercise.id }) {
            return
        }

        let highestIndex = session.sets.map { $0.orderIndex }.max() ?? 0
        let nextIndex = highestIndex + 1
        
        let savedUnit = UserDefaults.standard.string(forKey: "unitSystem")
        let isMetric = (savedUnit == "metric")
        let unitToUse = exercise.defaultUnit(isMetric: isMetric)
        
        // Auto-fill weight logic...
        var weightToUse = weight
        if weight == 0 {
            if let lastSet = session.sets.filter({ $0.exercise == exercise }).last {
                weightToUse = lastSet.weight
            }
        }
        
        let newSet = WorkoutSet(weight: weightToUse, reps: reps, orderIndex: nextIndex, unit: unitToUse)
        newSet.exercise = exercise
        newSet.workoutSession = session
        
        context.insert(newSet)
    }
    
    // MARK: - NEW: Replace Exercise
    func replaceExercise(oldExercise: Exercise, newExercise: Exercise) {
        guard let session = currentSession, let context = modelContext else { return }
        
        // Find sets for the old exercise
        let setsToUpdate = session.sets.filter { $0.exercise?.id == oldExercise.id }
        
        // Update them
        for set in setsToUpdate {
            set.exercise = newExercise
            
            // If swapping types (e.g. Strength -> Cardio), reset data to avoid confusion
            if oldExercise.type != newExercise.type {
                set.weight = 0
                set.reps = 0
                set.distance = 0
                set.duration = 0
                set.steps = 0
                
                // Smart Unit Reset — follow the new exercise's tracking type
                let isMetric = UserDefaults.standard.string(forKey: "unitSystem") == "metric"
                set.unit = newExercise.defaultUnit(isMetric: isMetric)
            }
        }
        
        context.saveLogging()
    }
    
    func completeSet(_ set: WorkoutSet) {
        set.isCompleted = true
        modelContext?.saveLogging()
    }
    
    func deleteSet(_ set: WorkoutSet) {
        modelContext?.delete(set)
    }
    
    /// Deletes the current session entirely (used when nothing was logged).
    func discardWorkout() {
        guard let session = currentSession, let context = modelContext else { return }
        stopWorkoutTimer()
        currentSession = nil
        context.delete(session) // cascade removes its sets
        context.saveLogging()
    }

    func finishWorkout() async {
        guard let session = currentSession else { return }
        session.isCompleted = true
        session.duration = TimeInterval(elapsedSeconds)
        // Save on the session's own (main) context — passing a main-context model
        // into the repository actor inserts it into a different context.
        do { try modelContext?.save() } catch { print("Error: \(error)") }
        stopWorkoutTimer()
        currentSession = nil
    }
    
    // MARK: - Timer Logic
    private func resumeSession(_ session: WorkoutSession) {
        self.currentSession = session
        if let start = session.startTime {
            self.elapsedSeconds = Int(Date().timeIntervalSince(start))
        }
        startWorkoutTimer()
    }
    
    private func startWorkoutTimer() {
        stopWorkoutTimer()
        if currentSession?.startTime == nil { currentSession?.startTime = Date() }
        guard let start = currentSession?.startTime else { return }
        
        isTimerRunning = true
        workoutTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let diff = Date().timeIntervalSince(start)
            self?.elapsedSeconds = Int(diff)
        }
    }
    
    private func stopWorkoutTimer() {
        isTimerRunning = false
        workoutTimer?.invalidate()
        workoutTimer = nil
        elapsedSeconds = 0
    }
}
