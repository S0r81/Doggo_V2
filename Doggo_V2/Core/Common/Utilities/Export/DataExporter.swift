//
//  DataExporter.swift
//  Doggo_V2
//
//  Exports workout data to CSV
//

import Foundation
import SwiftData

struct DataExporter {
    
    // 1. Generate the String content
    static func generateCSV(from sessions: [WorkoutSession]) -> String {
        var csvString = "Date,Routine Name,Exercise,Muscle Group,Type,Set Order,Weight (lbs),Reps,Steps,Distance,Duration (min),Note\n"
        
        // Sort sessions by date (newest first)
        let sortedSessions = sessions.sorted { $0.date > $1.date }
        
        for session in sortedSessions {
            let dateStr = session.date.formatted(date: .numeric, time: .omitted)
            let routineName = session.name.replacingOccurrences(of: ",", with: " ")
            
            let sortedSets = session.sets.sorted { $0.orderIndex < $1.orderIndex }
            
            for set in sortedSets {
                guard let exercise = set.exercise else { continue }
                
                let exName = exercise.name.replacingOccurrences(of: ",", with: " ")
                let muscle = exercise.muscleGroup
                let type = exercise.type
                let order = set.orderIndex + 1
                
                // Metrics
                let weight = String(format: "%.1f", set.weight)
                let reps = "\(set.reps)"
                
                // Cardio Metrics (Handle optionals)
                let steps = set.steps != nil ? "\(set.steps!)" : ""
                let distance = set.distance != nil ? String(format: "%.2f %@", set.distance!, set.unit) : ""
                let duration = set.duration != nil ? String(format: "%.1f", set.duration!) : ""
                
                // Note
                let note = set.routineItem?.note?.replacingOccurrences(of: ",", with: " ") ?? ""
                
                let row = "\(dateStr),\(routineName),\(exName),\(muscle),\(type),\(order),\(weight),\(reps),\(steps),\(distance),\(duration),\(note)\n"
                csvString.append(row)
            }
        }
        
        return csvString
    }
    
    // 2. Create the physical file (This was missing!)
    static func createCSVFile(from sessions: [WorkoutSession]) -> URL? {
        let csvData = generateCSV(from: sessions)
        let fileName = "Doggo_Export_\(Date().formatted(date: .numeric, time: .omitted)).csv"
            .replacingOccurrences(of: "/", with: "-") // Sanitize filename
        
        if let tempDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            do {
                try csvData.write(to: fileURL, atomically: true, encoding: .utf8)
                return fileURL
            } catch {
                print("Error creating CSV file: \(error)")
                return nil
            }
        }
        return nil
    }
}
