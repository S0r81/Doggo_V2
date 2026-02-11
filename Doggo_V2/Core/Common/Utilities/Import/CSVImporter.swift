//
//  CSVImporter.swift
//  Doggo
//
//  Created by Sorest on 1/19/26.
//

import Foundation

struct CSVImporter {
    
    struct ImportedSession: Identifiable {
        let id = UUID()
        let date: Date
        let name: String
        let duration: TimeInterval
        var exercises: [ImportedExercise]
    }
    
    struct ImportedExercise: Identifiable {
        let id = UUID()
        let name: String
        var sets: [ImportedSet]
    }
    
    struct ImportedSet: Identifiable {
        let id = UUID()
        let weight: Double
        let reps: Double
        let distance: Double?
        let time: Double?
        let unit: String
    }
    
    static func parseCSV(from text: String) -> [ImportedSession] {
        var sessions: [ImportedSession] = []
        let rows = text.components(separatedBy: .newlines)
        
        var currentSessionID: String? = nil
        var currentSession: ImportedSession? = nil
        
        for row in rows.dropFirst() {
            let columns = row.components(separatedBy: ",")
            if columns.count < 10 { continue }
            
            // 1. Extract Raw Data
            let dateString = columns[0]
            let workoutName = columns[1]
            let durationMin = Double(columns[2]) ?? 0
            let exerciseName = columns[3]
            let weight = Double(columns[5]) ?? 0
            let reps = Double(columns[6]) ?? 0
            let distance = Double(columns[7])
            let time = Double(columns[8])
            let unit = columns[9].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 2. Parse Date (With Time)
            let date = parseDate(dateString)
            
            // 3. Session Grouping
            let sessionKey = "\(dateString)-\(workoutName)"
            
            if currentSessionID != sessionKey {
                if let s = currentSession { sessions.append(s) }
                currentSessionID = sessionKey
                currentSession = ImportedSession(date: date, name: workoutName, duration: durationMin * 60, exercises: [])
            }
            
            // 4. Build Set
            let newSet = ImportedSet(weight: weight, reps: reps, distance: distance, time: time, unit: unit)
            
            // 5. Add to Exercise
            if let lastExIndex = currentSession?.exercises.indices.last,
               currentSession?.exercises[lastExIndex].name == exerciseName {
                currentSession?.exercises[lastExIndex].sets.append(newSet)
            } else {
                let newExercise = ImportedExercise(name: exerciseName, sets: [newSet])
                currentSession?.exercises.append(newExercise)
            }
        }
        
        if let s = currentSession { sessions.append(s) }
        return sessions
    }
    
    private static func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        
        // Attempt 1: Full Date & Time (e.g., "1/19/2026, 5:30 PM")
        // FIXED: Changed .numeric (invalid) to .short
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        if let date = formatter.date(from: dateString) { return date }
        
        // Attempt 2: Just Date (Backwards compatibility for old CSVs)
        formatter.timeStyle = .none
        if let date = formatter.date(from: dateString) {
            // Default to Noon if time is missing
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        }
        
        // Attempt 3: Fixed Format Fallback (Handles variations)
        formatter.dateFormat = "M/d/yyyy h:mm a"
        if let date = formatter.date(from: dateString) { return date }
        
        return Date()
    }
}

