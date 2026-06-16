//
//  Exercise.swift
//  Doggo_V2
//

import SwiftData
import Foundation

/// Typed view over the stored `type` string — cardio and strength flow
/// through completely different logging UIs.
enum ExerciseCategory {
    case strength
    case cardio
}

/// How a cardio exercise is measured. Backed by the existing `cardioType`
/// String column — raw values match the legacy stored strings ("Distance",
/// "Steps", "Time"), so no SwiftData migration is needed.
enum CardioTrackingType: String, Codable, CaseIterable, Identifiable {
    case distance = "Distance"
    case steps = "Steps"
    case floors = "Floors"
    case laps = "Laps"
    case timeOnly = "Time"

    var id: String { rawValue }

    /// Picker / display label.
    var label: String {
        switch self {
        case .distance: return "Distance"
        case .steps: return "Steps"
        case .floors: return "Floors"
        case .laps: return "Laps"
        case .timeOnly: return "Time Only"
        }
    }

    /// Label for the secondary input field; nil means time is the only metric.
    var metricLabel: String? {
        switch self {
        case .distance: return "Distance"
        case .steps: return "Steps"
        case .floors: return "Floors"
        case .laps: return "Laps"
        case .timeOnly: return nil
        }
    }

    /// Unit string written into WorkoutSet.unit (and the CSV Unit column).
    /// Distance resolves to mi/km at logging time.
    var countUnit: String? {
        switch self {
        case .steps: return "steps"
        case .floors: return "floors"
        case .laps: return "laps"
        case .distance, .timeOnly: return nil
        }
    }

    var icon: String {
        switch self {
        case .distance: return "point.topleft.down.curvedto.point.bottomright.up"
        case .steps: return "shoe.2.fill"
        case .floors: return "figure.stairs"
        case .laps: return "figure.pool.swim"
        case .timeOnly: return "clock"
        }
    }

    /// Tolerant parse for any stored/imported string. Unknown values fall
    /// back safely instead of crashing.
    static func from(_ raw: String) -> CardioTrackingType {
        if let exact = CardioTrackingType(rawValue: raw) { return exact }
        switch raw.trimmingCharacters(in: .whitespaces).lowercased() {
        case "distance": return .distance
        case "steps": return .steps
        case "floors": return .floors
        case "laps": return .laps
        case "time", "timeonly", "time only", "duration", "min": return .timeOnly
        default: return .distance
        }
    }

    /// Infers tracking from CSV row data (legacy files have no tracking column).
    static func inferred(fromUnit unit: String, hasDistance: Bool) -> CardioTrackingType {
        switch unit.trimmingCharacters(in: .whitespaces).lowercased() {
        case "steps": return .steps
        case "floors": return .floors
        case "laps": return .laps
        case "mi", "km": return .distance
        case "min": return .timeOnly
        default: return hasDistance ? .distance : .timeOnly
        }
    }
}

@Model
class Exercise {
    var id: UUID
    var name: String
    var type: String // "Strength", "Cardio", "Olympic", "Accessory"
    var muscleGroup: String
    var cardioType: String // "Distance" | "Steps" | "Time"
    
    // MARK: - NEW PROPERTIES
    var isFavorite: Bool = false
    var isCustom: Bool = false // If true, user can delete it.
    
    @Relationship(deleteRule: .cascade)
    var sets: [WorkoutSet] = []
    
    // Adding inverse relationships so SwiftData knows to nullify the reference in RoutineItem
    // if this exercise is ever deleted. This prevents the "backing data could no longer be found" crash.
    @Relationship(inverse: \RoutineItem.exercise)
    var routineItems: [RoutineItem] = []
    
    init(
        name: String,
        type: String = "Strength",
        muscleGroup: String = "Other",
        cardioType: String = "Distance",
        isCustom: Bool = true // Default to true for new user-created exercises
    ) {
        self.id = UUID()
        self.name = name
        self.type = type
        self.muscleGroup = muscleGroup
        self.cardioType = cardioType
        self.isCustom = isCustom
        self.isFavorite = false
    }
}

extension Exercise {
    /// `type` stays a String for SwiftData migration safety; use these for logic.
    var category: ExerciseCategory {
        type == "Cardio" ? .cardio : .strength
    }

    var isCardio: Bool { category == .cardio }

    /// Typed access to the stored `cardioType` string.
    var cardioTracking: CardioTrackingType {
        get { CardioTrackingType.from(cardioType) }
        set { cardioType = newValue.rawValue }
    }

    /// The unit a fresh WorkoutSet should carry for this exercise.
    func defaultUnit(isMetric: Bool) -> String {
        guard isCardio else { return isMetric ? "kg" : "lbs" }
        if let countUnit = cardioTracking.countUnit { return countUnit }
        if cardioTracking == .timeOnly { return "min" }
        return isMetric ? "km" : "mi"
    }
}
