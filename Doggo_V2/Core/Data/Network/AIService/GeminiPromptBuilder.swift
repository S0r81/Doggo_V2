//
//  GeminiPromptBuilder.swift
//  Doggo_V2
//
//  Builds all AI prompts
//

import Foundation

struct GeminiPromptBuilder {
    
    // MARK: - 1. Coach Analysis Prompt
    static func buildAnalysisPrompt(
        sessions: [WorkoutSession],
        profile: UserProfile?
    ) -> String {
        let stats = calculateStats(from: sessions)
        let recentHistory = sessions.sorted { $0.date > $1.date }.prefix(10)
        var historyString = ""
        
        for session in recentHistory {
            let date = session.date.formatted(date: .numeric, time: .omitted)
            historyString += "- \(date): \(session.name) (\(Int(session.duration/60)) min)\n"
            
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            let heavySets = sortedSets.filter { $0.weight > 0 }.prefix(8)
            
            for set in heavySets {
                if let name = set.exercise?.name {
                    historyString += "  * \(name): \(Int(set.weight)) \(set.unit) x \(set.reps)\n"
                }
            }
        }
        
        var userContext = "User Profile: Unknown"
        if let p = profile {
            userContext = """
            User Profile:
            - Goal: \(p.fitnessGoal)
            - Experience: \(p.experienceLevel)
            """
        }
        
        return """
        You are an elite strength and conditioning coach. Analyze this user's recent training data.
        
        \(userContext)
        
        QUANTITATIVE DATA (Last 30 Days):
        - Workout Consistency: \(stats.workoutsPerWeek) sessions/week
        - Avg Session Duration: \(stats.avgDuration)
        - Muscle Focus Split: \(stats.muscleSplit)
        - Total Volume: \(stats.totalVolume) lbs
        
        RECENT ACTIVITY LOG (Newest first):
        \(historyString)
        
        YOUR MISSION:
        1. Compare "Muscle Focus" vs "Goal".
        2. Analyze Consistency & Duration.
        3. Check for OVERLAP/RECOVERY issues.
        4. Provide 3 specific, actionable bullet points for next week (e.g. specific rep ranges, exercises to add/remove).
        
        Keep the advice short, punchy, and data-backed. Use Markdown.
        """
    }
    
    // MARK: - 2. Routine Generation Prompt
    static func buildRoutinePrompt(
        history: [WorkoutSession],
        availableExercises: [Exercise],
        profile: UserProfile?,
        focus: String,
        duration: Int,
        exerciseCount: Int,
        includeCardio: Bool,
        cardioDuration: Int,
        coachAdvice: String?
    ) -> String {
        let exerciseList = availableExercises.map { $0.name }.joined(separator: ", ")
        
        var userContext = ""
        if let p = profile {
            userContext = """
            User Profile:
            - Goal: \(p.fitnessGoal)
            - Experience: \(p.experienceLevel)
            """
        }
        
        let adviceContext = (coachAdvice != nil && !coachAdvice!.isEmpty) ? "COACH'S STRATEGY: \(coachAdvice!)" : "COACH'S STRATEGY: None."
        
        var maxWeights: [String: Double] = [:]
        var cardioCounts: [String: Int] = [:]
        
        for session in history.prefix(30) {
            for set in session.sets {
                guard let name = set.exercise?.name else { continue }
                if set.weight > (maxWeights[name] ?? 0) { maxWeights[name] = set.weight }
                if set.distance != nil { cardioCounts[name, default: 0] += 1 }
            }
        }
        
        let performanceContext = maxWeights.map { "- \($0.key): Best \($0.value) lbs" }.joined(separator: "\n")
        let favoriteCardio = cardioCounts.sorted { $0.value > $1.value }.first?.key ?? "Treadmill"
        
        return """
        You are an expert strength coach. Create a custom workout routine menu.
        
        \(userContext)
        \(adviceContext)
        
        USER REQUEST: Focus: \(focus), Time: \(duration) min.
        CONSTRAINT: EXACTLY \(exerciseCount) exercises.
        CARDIO REQUEST: \(includeCardio ? "Yes, include a cardio finisher." : "No cardio.")
        CARDIO DURATION: \(cardioDuration) min (if applicable).
        
        My Available Exercises: [\(exerciseList)]
        
        My Stats:
        \(performanceContext)
        Favorite Cardio: \(favoriteCardio)
        
        INSTRUCTIONS:
        1. Select EXACTLY \(exerciseCount) exercises matching the focus.
        2. CRITICAL: Apply the 'COACH'S STRATEGY' to the Sets/Reps.
        3. Use my Strength Levels to suggest specific target weights.
        4. IF CARDIO IS REQUESTED:
           - The LAST exercise MUST be a cardio exercise.
           - Prioritize my "Favorite Cardio" (\(favoriteCardio)) if it fits the goal, otherwise suggest the best option.
           - Sets: 1
           - Reps: "\(cardioDuration) min"
           - Note: Suggest intensity (e.g. "Zone 2" or "HIIT intervals").
        5. Return RAW JSON ONLY.
        
        JSON Format:
        {
            "routineName": "Routine Name",
            "exercises": [
                { "name": "Exact Exercise Name", "sets": 3, "reps": "8-12", "note": "Target: 135lbs" }
            ]
        }
        """
    }
    
    // MARK: - 3. Weekly Schedule Prompt
    static func buildSchedulePrompt(
        profile: UserProfile,
        history: [WorkoutSession],
        coachAdvice: String
    ) -> String {
        var lastWorkoutContext = "No recent workouts."
        if let last = history.sorted(by: { $0.date > $1.date }).first {
            lastWorkoutContext = "Last workout was '\(last.name)' on \(last.date.formatted(date: .abbreviated, time: .omitted))."
        }
        
        let adviceContext = coachAdvice.isEmpty ? "No specific advice yet." : coachAdvice
        
        return """
        Act as a personal trainer. Create a 7-day workout schedule (Monday to Sunday) for this user.
        
        USER PROFILE:
        - Goal: \(profile.fitnessGoal)
        - Experience: \(profile.experienceLevel)
        - PREFERRED SPLIT: \(profile.splitPreference)
        
        CONTEXT:
        - \(lastWorkoutContext)
        
        COACH'S RECENT ADVICE:
        "\(adviceContext)"
        
        INSTRUCTIONS:
        1. Create a plan for the UPCOMING week (Mon-Sun).
        2. PRIORITIZE THE COACH'S ADVICE.
        3. Respect the user's Preferred Split, but adjust it to fit the Coach's advice.
        4. If they just did 'Legs', ensure Monday isn't Legs (recovery).
        5. For the 'focus' field, USE ONLY STANDARD SPLIT NAMES (e.g. 'Push', 'Pull', 'Legs', 'Upper Body', 'Lower Body', 'Full Body', 'Cardio', 'Rest').
        6. Return RAW JSON ONLY.
        
        JSON Format:
        {
            "weekFocus": "Brief 1-sentence focus for the week",
            "days": [
                { "day": "Monday", "focus": "Push", "description": "Chest, Shoulders, Triceps" },
                ... (for all 7 days)
            ]
        }
        """
    }
    
    // MARK: - 4. Routine Content Prompt (Auto-fill)
    static func buildRoutineContentPrompt(
        routineName: String,
        profile: UserProfile?
    ) -> String {
        let goal = profile?.fitnessGoal ?? "General Fitness"
        let level = profile?.experienceLevel ?? "Beginner"
        
        return """
        Act as an expert fitness coach. Create a workout session for a routine named: "\(routineName)".
        User Goal: \(goal)
        User Level: \(level)
        
        INSTRUCTIONS:
        1. List 4-7 appropriate exercises.
        2. Provide standard sets/reps (e.g. 3 sets of 10).
        3. Use standard exercise names (e.g. "Squat", "Bench Press").
        
        OUTPUT JSON ONLY:
        [
            { "name": "Exercise Name", "sets": 3, "reps": 10, "note": "Brief tip" }
        ]
        """
    }
    
    // MARK: - 5. File Import Prompt (Cardio Support Added)
        
        static func buildImportPrompt(
            text: String,
            validExercises: [Exercise]
        ) -> String {
            let validNames = validExercises.map { $0.name }.joined(separator: ", ")
            
            return """
            You are a Data Structuring Specialist. Convert this unstructured workout text into valid JSON.
            
            INPUT TEXT:
            "\(text.prefix(20000))"
            
            MY VALID EXERCISE DATABASE:
            [\(validNames)]
            
            INSTRUCTIONS:
            1. Identify distinct Routines (e.g. "Day 1", "Push Day").
            2. EXTRACT WORKING SETS ONLY. Ignore generic warm-ups.
            3. MAPPING RULE: Match exercises to my database exactly if possible.
            4. CATEGORIZATION:
               - Infer "suggestedMuscle" (e.g. Chest, Legs, Cardio).
               - Infer "suggestedType" (Strength, Cardio, Flexibility).
               - Infer "suggestedCardioType" if it's cardio (Options: "Distance", "Steps", "Time").
            5. EXTRACT METRICS (CRITICAL):
               - "sets": Number of sets.
               - "reps": Standard rep count (for weights).
               - "weight": Weight used (if listed).
               - "steps": INT. Extract step count (e.g. "500 steps").
               - "distance": FLOAT. Extract distance (e.g. "5km", "3 miles").
               - "duration": FLOAT. Extract time in MINUTES (e.g. "30 mins" -> 30.0).
               - "note": Tips/Intensity (e.g. "Zone 2").
            
            JSON OUTPUT FORMAT:
            [
                {
                    "routineName": "Day 1",
                    "exercises": [
                        {
                            "originalName": "Stairmaster",
                            "mappedName": "Stairmaster",
                            "confidence": "High",
                            "sets": 1,
                            "reps": "0",
                            "steps": 500,
                            "distance": 0.0,
                            "duration": 20.0,
                            "suggestedMuscle": "Legs",
                            "suggestedType": "Cardio",
                            "suggestedCardioType": "Steps",
                            "note": "Warmup"
                        }
                    ]
                }
            ]
            """
        }
    // MARK: - 6. Set Suggestion Prompt
    static func buildSetSuggestionPrompt(
        exerciseName: String,
        history: [HistoryContext],
        goal: String
    ) -> String {
        let historyList = history.prefix(5).map { item in
            "- \(item.date.formatted(date: .numeric, time: .omitted)): \(Int(item.weight)) lbs x \(item.reps)"
        }.joined(separator: "\n")
        
        let contextString = historyList.isEmpty ? "No previous history for this exercise." : historyList
        
        return """
        Act as an expert strength coach. Suggest the Weight and Reps for the NEXT set of: "\(exerciseName)".
        
        USER GOAL: \(goal)
        
        RECENT HISTORY (Oldest to Newest):
        \(contextString)
        
        INSTRUCTIONS:
        1. Apply Progressive Overload. If they hit their reps last time, increase weight slightly (2.5-5 lbs).
        2. If they struggled (low reps), keep weight same or lower.
        3. If history is empty, suggest a conservative starting point for a beginner.
        4. "reasoning" should be very short (max 10 words).
        
        OUTPUT JSON ONLY:
        { "weight": 135.0, "reps": 10, "reasoning": "Increased weight by 5lbs due to good volume." }
        """
    }
    
    // MARK: - Helper: Calculate Stats
    private static func calculateStats(from sessions: [WorkoutSession]) -> AnalysisStats {
        let oneMonthAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let recentSessions = sessions.filter { $0.date > oneMonthAgo }
        
        let freq = String(format: "%.1f", Double(recentSessions.count) / 4.0)
        
        let totalSeconds = recentSessions.reduce(0) { $0 + $1.duration }
        let avgSeconds = recentSessions.isEmpty ? 0 : totalSeconds / Double(recentSessions.count)
        let avgDur = "\(Int(avgSeconds / 60)) min"
        
        var vol: Double = 0
        var muscleCounts: [String: Int] = [:]
        
        for session in recentSessions {
            for set in session.sets {
                let w = set.unit == "kg" ? set.weight * 2.2 : set.weight
                vol += (w * Double(set.reps))
                
                if let muscle = set.exercise?.muscleGroup {
                    muscleCounts[muscle, default: 0] += 1
                }
            }
        }
        
        let sortedMuscles = muscleCounts.sorted { $0.value > $1.value }.prefix(3)
        let splitString = sortedMuscles.map { "\($0.key) (\($0.value) sets)" }.joined(separator: ", ")
        
        return AnalysisStats(
            workoutsPerWeek: freq,
            avgDuration: avgDur,
            muscleSplit: splitString.isEmpty ? "General Full Body" : splitString,
            totalVolume: "\(Int(vol))"
        )
    }
}

// MARK: - Helper Struct
private struct AnalysisStats {
    let workoutsPerWeek: String
    let avgDuration: String
    let muscleSplit: String
    let totalVolume: String
}
