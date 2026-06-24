//
//  DataSeeder.swift
//  Doggo
//
//  Created by Sorest on 1/6/26.
//

import SwiftData
import Foundation

class DataSeeder {
    /// Checks if the database is empty. If yes, populates it with default exercises.
    @MainActor
    static func seedExercises(context: ModelContext) {
        // 1. Check if we already have exercises
        let descriptor = FetchDescriptor<Exercise>()
        let count = try? context.fetchCount(descriptor)
        
        // Only seed if the database is completely empty
        guard count == 0 else { return }
        
        DLog("Database empty. Seeding default exercises...")
        
        // 2. The Big List of Defaults
        let defaults: [(name: String, muscle: String, type: String)] = [
            // Chest
            ("Bench Press (Barbell)", "Chest", "Strength"),
            ("Bench Press (Dumbbell)", "Chest", "Strength"),
            ("Incline Bench Press", "Chest", "Strength"),
            ("Chest Fly", "Chest", "Strength"),
            ("Push Ups", "Chest", "Strength"),
            ("Dips", "Chest", "Strength"),
            ("Cable Crossover", "Chest", "Strength"),
            
            // Back
            ("Pull Up", "Back", "Strength"),
            ("Lat Pulldown", "Back", "Strength"),
            ("Barbell Row", "Back", "Strength"),
            ("Dumbbell Row", "Back", "Strength"),
            ("Deadlift", "Back", "Strength"),
            ("Face Pull", "Back", "Strength"),
            ("Seated Cable Row", "Back", "Strength"),
            
            // Legs
            ("Squat (Barbell)", "Legs", "Strength"),
            ("Leg Press", "Legs", "Strength"),
            ("Lunge", "Legs", "Strength"),
            ("Leg Extension", "Legs", "Strength"),
            ("Leg Curl", "Legs", "Strength"),
            ("Calf Raise", "Legs", "Strength"),
            ("Romanian Deadlift", "Legs", "Strength"),
            ("Bulgarian Split Squat", "Legs", "Strength"),
            
            // Shoulders
            ("Overhead Press (Barbell)", "Shoulders", "Strength"),
            ("Overhead Press (Dumbbell)", "Shoulders", "Strength"),
            ("Lateral Raise", "Shoulders", "Strength"),
            ("Front Raise", "Shoulders", "Strength"),
            ("Arnold Press", "Shoulders", "Strength"),
            ("Shrugs", "Shoulders", "Strength"),
            
            // Arms
            ("Bicep Curl (Barbell)", "Arms", "Strength"),
            ("Bicep Curl (Dumbbell)", "Arms", "Strength"),
            ("Hammer Curl", "Arms", "Strength"),
            ("Tricep Extension", "Arms", "Strength"),
            ("Skullcrusher", "Arms", "Strength"),
            ("Tricep Pushdown", "Arms", "Strength"),
            ("Preacher Curl", "Arms", "Strength"),
            
            // Core
            ("Crunch", "Core", "Strength"),
            ("Plank", "Core", "Strength"),
            ("Leg Raise", "Core", "Strength"),
            ("Russian Twist", "Core", "Strength"),
            ("Ab Wheel Rollout", "Core", "Strength"),
            
        ]

        // Cardio — each entry carries its tracking type so the session block
        // shows the right metric (distance vs floors vs laps vs time-only).
        let cardioDefaults: [(name: String, tracking: CardioTrackingType)] = [
            ("Running (Outdoor)", .distance),
            ("Treadmill", .distance),
            ("Cycling", .distance),
            ("Rowing Machine", .distance),
            ("Jump Rope", .timeOnly),
            ("Elliptical", .distance),
            ("Stairmaster", .floors),
            ("Swimming", .laps),
            ("Yoga", .timeOnly)
        ]

        // 3. Loop and Insert
        for item in defaults {
            let exercise = Exercise(name: item.name, type: item.type, muscleGroup: item.muscle)
            context.insert(exercise)
        }

        for item in cardioDefaults {
            let exercise = Exercise(
                name: item.name,
                type: "Cardio",
                muscleGroup: "Cardio",
                cardioType: item.tracking.rawValue
            )
            context.insert(exercise)
        }
        
        // 4. Save
        do {
            try context.save()
            DLog("Success! Seeded \(defaults.count + cardioDefaults.count) exercises.")
        } catch {
            DLog("Failed to seed exercises: \(error)")
        }
    }
}

