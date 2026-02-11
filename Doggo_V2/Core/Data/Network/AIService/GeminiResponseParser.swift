//
//  GeminiResponseParser.swift
//  Doggo_V2
//
//  Parses all AI responses
//

import Foundation

struct GeminiResponseParser {
    
    // MARK: - 1. Parse Routine Response
    
    static func parseRoutine(_ text: String) throws -> (name: String, rawJSON: String, items: [AIRoutineItem]) {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw ParsingError.noJSON
        }
        
        let jsonString = String(text[start...end])
        
        guard let data = jsonString.data(using: .utf8),
              let responseObj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = responseObj["routineName"] as? String,
              let exercises = responseObj["exercises"] as? [[String: Any]]
        else {
            throw ParsingError.invalidFormat
        }
        
        let mappedItems = exercises.compactMap { dict -> AIRoutineItem? in
            guard let exName = dict["name"] as? String else { return nil }
            let sets = dict["sets"] as? Int ?? 3
            let repsVal = dict["reps"]
            let repsString = "\(repsVal ?? "10")"
            let note = dict["note"] as? String ?? ""
            return AIRoutineItem(name: exName, sets: sets, reps: repsString, note: note)
        }
        
        return (name, jsonString, mappedItems)
    }
    
    // MARK: - 2. Parse Weekly Schedule
    
    static func parseSchedule(_ text: String) throws -> WeeklyPlan {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            throw ParsingError.noJSON
        }
        
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else {
            throw ParsingError.invalidEncoding
        }
        
        return try JSONDecoder().decode(WeeklyPlan.self, from: data)
    }
    
    // MARK: - 3. Parse Import Data
    
    static func parseImport(_ text: String) throws -> [AIImportedRoutine] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            print("❌ Could not find JSON array brackets.")
            throw ParsingError.noJSON
        }
        
        let jsonString = String(text[start...end])
        print("🔍 RAW AI JSON: \(jsonString)")
        
        guard let data = jsonString.data(using: .utf8) else {
            throw ParsingError.invalidEncoding
        }
        
        return try JSONDecoder().decode([AIImportedRoutine].self, from: data)
    }
    
    // MARK: - 4. Parse Set Suggestion
    
    static func parseSetSuggestion(_ text: String) throws -> SetSuggestion {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else {
            // Return default instead of throwing
            return SetSuggestion(weight: 0, reps: 0, reasoning: "Parse error")
        }
        
        let jsonStr = String(text[start...end])
        guard let data = jsonStr.data(using: .utf8) else {
            return SetSuggestion(weight: 0, reps: 0, reasoning: "Encoding error")
        }
        
        return try JSONDecoder().decode(SetSuggestion.self, from: data)
    }
    
    // MARK: - 5. Parse Exercise List (Routine Content)
    
    static func parseExerciseList(_ text: String) throws -> [AIGeneratedExercise] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]") else {
            return []
        }
        
        let jsonString = String(text[start...end])
        guard let data = jsonString.data(using: .utf8) else {
            return []
        }
        
        return try JSONDecoder().decode([AIGeneratedExercise].self, from: data)
    }
    
    // MARK: - 6. Parse Analysis (Just clean text)
    
    static func parseAnalysis(_ text: String) -> String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Parsing Errors

enum ParsingError: LocalizedError {
    case noJSON
    case invalidEncoding
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .noJSON:
            return "No JSON found in response"
        case .invalidEncoding:
            return "Invalid text encoding"
        case .invalidFormat:
            return "Invalid JSON format"
        }
    }
}
