//
//  DataExporter.swift
//  Doggo_V2
//
//  Exports workout data to CSV with a clean, data-analysis friendly schema.
//

import Foundation
import SwiftData

struct DataExporter {
    
    static func createCSVFile(from sessions: [WorkoutSession]) -> URL? {
        
        // 1. The Clean Header
        var csvString = "Date,Routine,Exercise,Group,Type,Set,Weight,Reps,Distance,Duration,Steps,Unit,Notes\n"
        
        // Date Formatter
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none
        
        // Sort sessions (Newest first)
        let sortedSessions = sessions.sorted { $0.date > $1.date }
        
        for session in sortedSessions {
            // Sort sets (1, 2, 3...)
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            
            for set in sortedSets {
                // MARK: - Basic Info
                let date = dateFormatter.string(from: session.date)
                
                let routineName = session.name.replacingOccurrences(of: ",", with: " ")
                let exercise = (set.exercise?.name ?? "Unknown").replacingOccurrences(of: ",", with: " ")
                let group = set.exercise?.muscleGroup ?? "-"
                let type = set.exercise?.type ?? "Strength"
                let setOrder = String(set.orderIndex + 1)
                
                // MARK: - Metric Logic
                var weight = ""
                var reps = ""
                var distance = ""
                var duration = ""
                var steps = ""
                var unit = set.unit
                
                if type == "Cardio" {
                    // --- CARDIO ROWS ---
                    if let d = set.distance, d > 0 { distance = String(format: "%.2f", d) }
                    if let t = set.duration, t > 0 { duration = String(format: "%.1f", t) }
                    if let s = set.steps, s > 0    { steps = String(s) }
                    
                    // 1. Sanitize "Weight" units on Cardio (lbs -> mi default)
                    if unit == "lbs" || unit == "kg" {
                        unit = "mi"
                    }
                    
                    // 2. Smart Fix: If we have steps but NO distance, it's a Step-based workout
                    // This fixes "Stair Master" showing as "mi"
                    if (set.steps ?? 0) > 0 && (set.distance ?? 0) == 0 {
                        unit = "steps"
                    }
                    
                } else {
                    // --- STRENGTH ROWS ---
                    if set.weight > 0 {
                        weight = String(format: "%.1f", set.weight)
                    } else {
                        weight = "0"
                    }
                    reps = String(set.reps)
                    
                    if let t = set.duration, t > 0 { duration = String(format: "%.1f", t) }
                }

                let noteContent = (session.notes ?? "").replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: ",", with: " ")
                
                // MARK: - Build Row
                let row = "\(date),\(routineName),\(exercise),\(group),\(type),\(setOrder),\(weight),\(reps),\(distance),\(duration),\(steps),\(unit),\(noteContent)\n"
                
                csvString.append(row)
            }
        }
        
        // MARK: - Save to Temp Directory
        let datePart = Date().formatted(date: .numeric, time: .omitted).replacingOccurrences(of: "/", with: "-")
        let fileName = "Doggo_Export_\(datePart).csv"
        
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error creating CSV: \(error)")
            return nil
        }
    }
}
