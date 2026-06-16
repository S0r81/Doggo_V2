//
//  ProgramCatalog.swift
//  Doggo_V2
//
//  Bundled, proven training programs. Defined in Swift (not JSON) so exercise
//  names are greppable against DataSeeder and content errors fail loudly in
//  review, not silently at runtime.
//

import Foundation

// MARK: - Definitions

struct ProgramDefinition: Identifiable {
    let id: String          // stable key, also written to Routine.sourceProgram
    let name: String
    let tagline: String
    let description: String
    let level: String       // matches onboarding experience levels
    let daysPerWeek: Int
    let goals: [String]     // matches onboarding goal strings
    let days: [ProgramDay]

    /// Default weekday placement by training frequency.
    var defaultWeekdays: [String] {
        switch daysPerWeek {
        case 2: return ["Monday", "Thursday"]
        case 3: return ["Monday", "Wednesday", "Friday"]
        case 4: return ["Monday", "Tuesday", "Thursday", "Friday"]
        default: return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
        }
    }
}

struct ProgramDay {
    let name: String
    let items: [ProgramItem]
}

struct ProgramItem {
    let exercise: String
    let muscleGroup: String   // used only if the exercise must be created
    let sets: Int
    let reps: Int
    /// Items sharing a non-nil group number become a superset.
    let supersetGroup: Int?

    init(_ exercise: String, _ muscleGroup: String, sets: Int, reps: Int, supersetGroup: Int? = nil) {
        self.exercise = exercise
        self.muscleGroup = muscleGroup
        self.sets = sets
        self.reps = reps
        self.supersetGroup = supersetGroup
    }
}

// MARK: - Catalog

enum ProgramCatalog {

    static let all: [ProgramDefinition] = [fullBody, upperLower, pushPullLegs, strength4Day, minimal2Day]

    /// Programs matching the user's onboarding answers, best match first.
    static func recommended(experience: String, goal: String) -> [ProgramDefinition] {
        all.sorted { a, b in
            score(a, experience: experience, goal: goal) > score(b, experience: experience, goal: goal)
        }
    }

    private static func score(_ program: ProgramDefinition, experience: String, goal: String) -> Int {
        var score = 0
        if program.level == experience { score += 2 }
        if program.goals.contains(goal) { score += 1 }
        return score
    }

    // MARK: - Content

    static let fullBody = ProgramDefinition(
        id: "full-body-foundations",
        name: "Full Body Foundations",
        tagline: "The classic 3-day starting point",
        description: "Every major movement pattern, three times a week. The fastest way for a newer lifter to build strength and learn the big lifts — plenty of recovery between sessions.",
        level: "Beginner",
        daysPerWeek: 3,
        goals: ["Build Muscle", "Strength", "General Health"],
        days: [
            ProgramDay(name: "Full Body A", items: [
                ProgramItem("Squat (Barbell)", "Legs", sets: 3, reps: 8),
                ProgramItem("Bench Press (Barbell)", "Chest", sets: 3, reps: 8),
                ProgramItem("Barbell Row", "Back", sets: 3, reps: 10),
                ProgramItem("Plank", "Core", sets: 3, reps: 30)
            ]),
            ProgramDay(name: "Full Body B", items: [
                ProgramItem("Deadlift", "Back", sets: 3, reps: 5),
                ProgramItem("Overhead Press (Barbell)", "Shoulders", sets: 3, reps: 8),
                ProgramItem("Lat Pulldown", "Back", sets: 3, reps: 10),
                ProgramItem("Leg Curl", "Legs", sets: 3, reps: 12)
            ]),
            ProgramDay(name: "Full Body C", items: [
                ProgramItem("Leg Press", "Legs", sets: 3, reps: 10),
                ProgramItem("Bench Press (Dumbbell)", "Chest", sets: 3, reps: 10),
                ProgramItem("Seated Cable Row", "Back", sets: 3, reps: 10),
                ProgramItem("Bicep Curl (Dumbbell)", "Arms", sets: 2, reps: 12, supersetGroup: 1),
                ProgramItem("Tricep Pushdown", "Arms", sets: 2, reps: 12, supersetGroup: 1)
            ])
        ]
    )

    static let upperLower = ProgramDefinition(
        id: "upper-lower-4day",
        name: "Upper / Lower",
        tagline: "Balanced 4-day split",
        description: "Two upper days, two lower days. Enough frequency to grow everything, enough volume per session to push hard — the workhorse split for intermediate lifters.",
        level: "Intermediate",
        daysPerWeek: 4,
        goals: ["Build Muscle", "Strength"],
        days: [
            ProgramDay(name: "Upper Power", items: [
                ProgramItem("Bench Press (Barbell)", "Chest", sets: 4, reps: 6),
                ProgramItem("Barbell Row", "Back", sets: 4, reps: 6),
                ProgramItem("Overhead Press (Barbell)", "Shoulders", sets: 3, reps: 8),
                ProgramItem("Lat Pulldown", "Back", sets: 3, reps: 10),
                ProgramItem("Bicep Curl (Barbell)", "Arms", sets: 3, reps: 10)
            ]),
            ProgramDay(name: "Lower Power", items: [
                ProgramItem("Squat (Barbell)", "Legs", sets: 4, reps: 6),
                ProgramItem("Romanian Deadlift", "Legs", sets: 3, reps: 8),
                ProgramItem("Leg Press", "Legs", sets: 3, reps: 10),
                ProgramItem("Calf Raise", "Legs", sets: 4, reps: 12),
                ProgramItem("Plank", "Core", sets: 3, reps: 45)
            ]),
            ProgramDay(name: "Upper Hypertrophy", items: [
                ProgramItem("Incline Bench Press", "Chest", sets: 3, reps: 10),
                ProgramItem("Seated Cable Row", "Back", sets: 3, reps: 10),
                ProgramItem("Lateral Raise", "Shoulders", sets: 3, reps: 15),
                ProgramItem("Chest Fly", "Chest", sets: 3, reps: 12),
                ProgramItem("Hammer Curl", "Arms", sets: 2, reps: 12, supersetGroup: 1),
                ProgramItem("Skullcrusher", "Arms", sets: 2, reps: 12, supersetGroup: 1)
            ]),
            ProgramDay(name: "Lower Hypertrophy", items: [
                ProgramItem("Deadlift", "Back", sets: 3, reps: 6),
                ProgramItem("Bulgarian Split Squat", "Legs", sets: 3, reps: 10),
                ProgramItem("Leg Extension", "Legs", sets: 3, reps: 12),
                ProgramItem("Leg Curl", "Legs", sets: 3, reps: 12),
                ProgramItem("Crunch", "Core", sets: 3, reps: 15)
            ])
        ]
    )

    static let pushPullLegs = ProgramDefinition(
        id: "push-pull-legs",
        name: "Push Pull Legs",
        tagline: "The classic bodybuilding split",
        description: "Push day for chest, shoulders, and triceps; pull day for back and biceps; leg day for everything below. Run it 3 days a week — or schedule it twice for a 6-day cycle.",
        level: "Intermediate",
        daysPerWeek: 3,
        goals: ["Build Muscle"],
        days: [
            ProgramDay(name: "Push Day", items: [
                ProgramItem("Bench Press (Barbell)", "Chest", sets: 4, reps: 8),
                ProgramItem("Overhead Press (Dumbbell)", "Shoulders", sets: 3, reps: 10),
                ProgramItem("Incline Bench Press", "Chest", sets: 3, reps: 10),
                ProgramItem("Lateral Raise", "Shoulders", sets: 3, reps: 15),
                ProgramItem("Tricep Pushdown", "Arms", sets: 3, reps: 12)
            ]),
            ProgramDay(name: "Pull Day", items: [
                ProgramItem("Deadlift", "Back", sets: 3, reps: 6),
                ProgramItem("Pull Up", "Back", sets: 3, reps: 8),
                ProgramItem("Barbell Row", "Back", sets: 3, reps: 10),
                ProgramItem("Face Pull", "Back", sets: 3, reps: 15),
                ProgramItem("Bicep Curl (Barbell)", "Arms", sets: 3, reps: 10)
            ]),
            ProgramDay(name: "Leg Day", items: [
                ProgramItem("Squat (Barbell)", "Legs", sets: 4, reps: 8),
                ProgramItem("Romanian Deadlift", "Legs", sets: 3, reps: 10),
                ProgramItem("Leg Press", "Legs", sets: 3, reps: 10),
                ProgramItem("Leg Curl", "Legs", sets: 3, reps: 12),
                ProgramItem("Calf Raise", "Legs", sets: 4, reps: 15)
            ])
        ]
    )

    static let strength4Day = ProgramDefinition(
        id: "strength-4day",
        name: "Strength 4-Day",
        tagline: "Heavy compounds, linear progression",
        description: "Each day is built around one big lift — squat, bench, deadlift, press — at low reps, backed by targeted accessories. Pair it with the progression engine to add weight every week.",
        level: "Advanced",
        daysPerWeek: 4,
        goals: ["Strength"],
        days: [
            ProgramDay(name: "Squat Day", items: [
                ProgramItem("Squat (Barbell)", "Legs", sets: 5, reps: 5),
                ProgramItem("Leg Press", "Legs", sets: 3, reps: 8),
                ProgramItem("Leg Curl", "Legs", sets: 3, reps: 10),
                ProgramItem("Plank", "Core", sets: 3, reps: 45)
            ]),
            ProgramDay(name: "Bench Day", items: [
                ProgramItem("Bench Press (Barbell)", "Chest", sets: 5, reps: 5),
                ProgramItem("Bench Press (Dumbbell)", "Chest", sets: 3, reps: 8),
                ProgramItem("Dips", "Chest", sets: 3, reps: 8),
                ProgramItem("Tricep Extension", "Arms", sets: 3, reps: 10)
            ]),
            ProgramDay(name: "Deadlift Day", items: [
                ProgramItem("Deadlift", "Back", sets: 5, reps: 3),
                ProgramItem("Barbell Row", "Back", sets: 3, reps: 8),
                ProgramItem("Lat Pulldown", "Back", sets: 3, reps: 10),
                ProgramItem("Leg Raise", "Core", sets: 3, reps: 12)
            ]),
            ProgramDay(name: "Press Day", items: [
                ProgramItem("Overhead Press (Barbell)", "Shoulders", sets: 5, reps: 5),
                ProgramItem("Incline Bench Press", "Chest", sets: 3, reps: 8),
                ProgramItem("Lateral Raise", "Shoulders", sets: 3, reps: 12),
                ProgramItem("Bicep Curl (Barbell)", "Arms", sets: 3, reps: 10)
            ])
        ]
    )

    static let minimal2Day = ProgramDefinition(
        id: "minimal-2day",
        name: "Minimal 2-Day",
        tagline: "Maximum result per gym hour",
        description: "For packed schedules: two full-body sessions hitting every major muscle with the highest-payoff lifts. Consistency beats volume — this is the program you'll actually stick to.",
        level: "Beginner",
        daysPerWeek: 2,
        goals: ["General Health", "Strength", "Lose Fat"],
        days: [
            ProgramDay(name: "Day 1 — Push Focus", items: [
                ProgramItem("Squat (Barbell)", "Legs", sets: 3, reps: 8),
                ProgramItem("Bench Press (Barbell)", "Chest", sets: 3, reps: 8),
                ProgramItem("Lat Pulldown", "Back", sets: 3, reps: 10),
                ProgramItem("Plank", "Core", sets: 2, reps: 45)
            ]),
            ProgramDay(name: "Day 2 — Pull Focus", items: [
                ProgramItem("Deadlift", "Back", sets: 3, reps: 5),
                ProgramItem("Overhead Press (Dumbbell)", "Shoulders", sets: 3, reps: 10),
                ProgramItem("Seated Cable Row", "Back", sets: 3, reps: 10),
                ProgramItem("Lunge", "Legs", sets: 2, reps: 10)
            ])
        ]
    )
}
