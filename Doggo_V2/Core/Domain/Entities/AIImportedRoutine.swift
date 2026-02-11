//
//  AIImportedRoutine.swift
//  Doggo_V2
//

import Foundation

struct AIImportedRoutine: Codable, Identifiable {
    var id: UUID = UUID()
    let routineName: String
    var exercises: [AIImportedExercise]
    
    enum CodingKeys: String, CodingKey {
        case routineName
        case exercises
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.routineName = try container.decodeIfPresent(String.self, forKey: .routineName) ?? "New Routine"
        self.exercises = try container.decodeIfPresent([AIImportedExercise].self, forKey: .exercises) ?? []
    }
    
    init(id: UUID = UUID(), routineName: String, exercises: [AIImportedExercise]) {
        self.id = id
        self.routineName = routineName
        self.exercises = exercises
    }
}

struct AIImportedExercise: Codable, Identifiable {
    var id: UUID = UUID()
    let originalName: String
    var mappedName: String
    var confidence: String
    
    // Metrics
    var sets: Int
    var reps: String
    var weight: Double? // New
    var steps: Int?     // New
    var distance: Double? // New
    var duration: Double? // New
    
    let note: String?
    let supersetLabel: String?
    
    // Categorization
    let suggestedMuscle: String?
    let suggestedType: String?
    let suggestedCardioType: String? // New
    
    var isNewExercise: Bool { confidence == "None" }
    
    enum CodingKeys: String, CodingKey {
        case originalName, mappedName, confidence, sets, reps, weight, steps, distance, duration, note, supersetLabel, suggestedMuscle, suggestedType, suggestedCardioType
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.originalName = try container.decodeIfPresent(String.self, forKey: .originalName) ?? "Unknown Exercise"
        self.mappedName = try container.decodeIfPresent(String.self, forKey: .mappedName) ?? "Unknown Exercise"
        self.confidence = try container.decodeIfPresent(String.self, forKey: .confidence) ?? "None"
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        self.supersetLabel = try container.decodeIfPresent(String.self, forKey: .supersetLabel)
        
        // Categorization
        self.suggestedMuscle = try container.decodeIfPresent(String.self, forKey: .suggestedMuscle)
        self.suggestedType = try container.decodeIfPresent(String.self, forKey: .suggestedType)
        self.suggestedCardioType = try container.decodeIfPresent(String.self, forKey: .suggestedCardioType)
        
        // Metrics Parsing
        if let setsInt = try? container.decode(Int.self, forKey: .sets) {
            self.sets = setsInt
        } else if let setsString = try? container.decode(String.self, forKey: .sets), let val = Int(setsString) {
            self.sets = val
        } else { self.sets = 3 }
        
        if let repsString = try? container.decode(String.self, forKey: .reps) {
            self.reps = repsString
        } else if let repsInt = try? container.decode(Int.self, forKey: .reps) {
            self.reps = String(repsInt)
        } else { self.reps = "10" }
        
        // New Metric Fields
        self.weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        self.steps = try container.decodeIfPresent(Int.self, forKey: .steps)
        self.distance = try container.decodeIfPresent(Double.self, forKey: .distance)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration)
    }
    
    // Manual Init
    init(
        id: UUID = UUID(),
        originalName: String,
        mappedName: String,
        confidence: String,
        sets: Int,
        reps: String,
        weight: Double? = nil,
        steps: Int? = nil,
        distance: Double? = nil,
        duration: Double? = nil,
        note: String?,
        supersetLabel: String?,
        suggestedMuscle: String? = nil,
        suggestedType: String? = nil,
        suggestedCardioType: String? = nil
    ) {
        self.id = id
        self.originalName = originalName
        self.mappedName = mappedName
        self.confidence = confidence
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.steps = steps
        self.distance = distance
        self.duration = duration
        self.note = note
        self.supersetLabel = supersetLabel
        self.suggestedMuscle = suggestedMuscle
        self.suggestedType = suggestedType
        self.suggestedCardioType = suggestedCardioType
    }
}
