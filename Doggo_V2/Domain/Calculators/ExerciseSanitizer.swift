//
//  ExerciseSanitizer.swift
//  Doggo_V2
//
//  Pure, actor-agnostic exercise-naming rules shared by every import path:
//  AI program generation (main context) and shared-program import (background
//  @ModelActor). Kept nonisolated so the background actor can call it without
//  hopping to the main actor.
//

import Foundation

nonisolated enum ExerciseSanitizer {

    /// "  bench press (barbell)!! " → "Bench Press Barbell" — strips anything
    /// that isn't a letter/digit/space/hyphen, collapses whitespace, then
    /// applies strict Title Case (hyphen segments capitalized; EZ/HIIT kept
    /// uppercase).
    static func sanitizeName(_ raw: String) -> String {
        var cleaned = ""
        for scalar in raw.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) || scalar == " " || scalar == "-" {
                cleaned.unicodeScalars.append(scalar)
            } else {
                cleaned.append(" ")
            }
        }

        let allCaps: Set<String> = ["ez", "hiit", "rdl", "ohp", "amrap"]
        func titleCase(_ segment: some StringProtocol) -> String {
            let lower = segment.lowercased()
            if allCaps.contains(lower) { return lower.uppercased() }
            return lower.prefix(1).uppercased() + lower.dropFirst()
        }

        return cleaned
            .split(separator: " ")
            .map { word in
                word.split(separator: "-").map(titleCase).joined(separator: "-")
            }
            .joined(separator: " ")
    }

    /// Order-insensitive identity: lowercase alphanumeric tokens, sorted.
    /// "Bench Press (Barbell)" and "Barbell Bench Press" share a key, so
    /// imports never produce duplicate exercises.
    static func canonicalKey(_ name: String) -> String {
        name.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: " ")
    }

    /// Constrains muscleGroup to the values the rest of the app understands
    /// (Progress tab muscle balance, exercise filters).
    static func normalizedMuscleGroup(_ raw: String, isCardio: Bool) -> String {
        let known = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio"]
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        if let match = known.first(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return match
        }
        return isCardio ? "Cardio" : "Other"
    }

    /// Default weekday placement by training-day count (matches the bundled
    /// program catalog).
    static func defaultWeekdays(forDayCount count: Int) -> [String] {
        switch count {
        case 2: return ["Monday", "Thursday"]
        case 3: return ["Monday", "Wednesday", "Friday"]
        case 4: return ["Monday", "Tuesday", "Thursday", "Friday"]
        case 5: return ["Monday", "Tuesday", "Wednesday", "Friday", "Saturday"]
        case 6: return ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        default: return Array(weekdayNames.prefix(max(0, count)))
        }
    }
}
