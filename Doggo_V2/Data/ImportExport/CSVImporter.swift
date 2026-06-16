//
//  CSVImporter.swift
//  Doggo_V2
//
//  Imports workout data from the new Clean Schema CSV.
//

import Foundation

struct CSVImporter {

    // MARK: - Intermediate Models
    // Sendable value types — these cross from the parsing task into the
    // WorkoutRepository @ModelActor, so they must not be SwiftData models.
    struct ImportedSession: Identifiable, Sendable {
        let id = UUID()
        let date: Date
        let name: String
        let duration: TimeInterval
        var exercises: [ImportedExercise]

        var totalSets: Int { exercises.reduce(0) { $0 + $1.sets.count } }
    }

    struct ImportedExercise: Identifiable, Sendable {
        let id = UUID()
        let name: String
        let muscleGroup: String // Added
        let type: String       // Added
        var sets: [ImportedSet]
    }

    struct ImportedSet: Identifiable, Sendable {
        let id = UUID()
        let weight: Double
        let reps: Double
        let distance: Double?
        let time: Double?
        let steps: Int?       // Added
        let unit: String
    }

    // MARK: - File Parsing (async, off-main)

    enum ImportError: LocalizedError {
        case unreadable
        case empty

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Couldn't read that file. Make sure it's a Doggo CSV export."
            case .empty: return "No workout sessions found in this CSV."
            }
        }
    }

    /// Reads a user-picked (security-scoped) file and parses it off the main
    /// thread, so a multi-year history doesn't hitch the UI.
    static func parse(fileURL: URL) async throws -> [ImportedSession] {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        guard let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            throw ImportError.unreadable
        }

        let sessions = await Task.detached(priority: .userInitiated) {
            parseCSV(from: text)
        }.value

        guard !sessions.isEmpty else { throw ImportError.empty }
        return sessions
    }

    // MARK: - Parsing Logic
    static func parseCSV(from text: String) -> [ImportedSession] {
        var sessions: [ImportedSession] = []
        let rows = text.components(separatedBy: .newlines)
        
        var currentSessionKey: String? = nil
        var currentSession: ImportedSession? = nil
        
        // Skip Header Row (dropFirst)
        for row in rows.dropFirst() {
            let columns = row.components(separatedBy: ",")
            
            // New Schema has 13 columns (indices 0-12)
            // We check for at least 12 to be safe
            guard columns.count >= 12 else { continue }
            
            // 1. Extract Data based on NEW SCHEMA
            // Header: Date, Routine, Exercise, Group, Type, Set, Weight, Reps, Distance, Duration, Steps, Unit, Notes
            
            let dateString   = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let workoutName  = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let exerciseName = columns[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let muscleGroup  = columns[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let type         = columns[4].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Metrics
            let weight       = Double(columns[6]) ?? 0.0
            let reps         = Double(columns[7]) ?? 0.0
            let distance     = Double(columns[8]) // Optional in CSV
            let duration     = Double(columns[9]) // Optional in CSV
            let steps        = Int(columns[10])   // Optional in CSV
            let unit         = columns[11].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 2. Parse Date
            let date = parseDate(dateString)
            
            // 3. Session Grouping (Key = "Date + RoutineName")
            let sessionKey = "\(dateString)-\(workoutName)"
            
            // If this row belongs to a new session
            if currentSessionKey != sessionKey {
                // Save previous session if it exists
                if let s = currentSession { sessions.append(s) }
                
                // Start new session
                currentSessionKey = sessionKey
                currentSession = ImportedSession(
                    date: date,
                    name: workoutName,
                    duration: 0, // Duration is no longer in CSV header, handled per set
                    exercises: []
                )
            }
            
            // 4. Build Set
            let newSet = ImportedSet(
                weight: weight,
                reps: reps,
                distance: distance,
                time: duration,
                steps: steps,
                unit: unit
            )
            
            // 5. Add to Exercise
            // Check if the last exercise in the current session matches this one
            if let lastExIndex = currentSession?.exercises.indices.last,
               currentSession?.exercises[lastExIndex].name == exerciseName {
                // Same exercise, just append the set
                currentSession?.exercises[lastExIndex].sets.append(newSet)
            } else {
                // New exercise found, create it
                let newExercise = ImportedExercise(
                    name: exerciseName,
                    muscleGroup: muscleGroup,
                    type: type,
                    sets: [newSet]
                )
                currentSession?.exercises.append(newExercise)
            }
        }
        
        // Append the final session loop
        if let s = currentSession { sessions.append(s) }
        
        return sessions
    }
    
    // MARK: - Helper: Date Parsing
    private static func parseDate(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        
        // Attempt 1: Short Date (Matches Exporter) -> "2/13/26"
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        if let date = formatter.date(from: dateString) {
            // Default to Noon since time is stripped in export
            return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        }
        
        // Attempt 2: Full Date (Legacy Fallback)
        formatter.dateFormat = "M/d/yyyy h:mm a"
        if let date = formatter.date(from: dateString) { return date }
        
        return Date()
    }
}
