//
//  AIGeneratedProgram.swift
//  Doggo_V2
//
//  Codable contract for AI-generated multi-day programs. Every provider
//  (Gemini / Claude / GPT / OpenRouter) returns this same JSON shape because
//  the schema is enforced at the shared prompt level, not per-client.
//
//  Decoding is deliberately tolerant: models occasionally emit numbers as
//  strings ("sets": "3") or omit optional fields — a recoverable response
//  should never throw.
//
//  All properties are `var`: the generator view holds the parsed result as an
//  editable draft (rename exercises, tweak sets/reps, delete rows) before it
//  is committed to the database. `id` exists only for SwiftUI list identity —
//  it is never part of the JSON.
//

import Foundation

struct AIGeneratedProgram: Codable, Sendable {
    var name: String
    var description: String
    var days: [Day]

    struct Day: Codable, Sendable, Identifiable {
        var id = UUID()
        var name: String
        var exercises: [ExercisePlan]

        enum CodingKeys: String, CodingKey {
            case name, exercises
        }
    }

    struct ExercisePlan: Codable, Sendable, Identifiable {
        var id = UUID()
        var name: String
        var muscleGroup: String
        /// "Strength" | "Cardio" — anything else is treated as Strength.
        var category: String
        /// Required for cardio: "Distance" | "Steps" | "Floors" | "Laps" | "Time".
        var cardioTracking: String?
        var sets: Int
        var reps: Int
        var note: String?

        var isCardio: Bool {
            category.trimmingCharacters(in: .whitespaces).lowercased() == "cardio"
        }

        /// Typed tracking, tolerant of casing/synonyms via CardioTrackingType.from.
        var resolvedTracking: CardioTrackingType {
            CardioTrackingType.from(cardioTracking ?? "Distance")
        }

        enum CodingKeys: String, CodingKey {
            case name, muscleGroup, category, cardioTracking, sets, reps, note
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            muscleGroup = (try? container.decode(String.self, forKey: .muscleGroup)) ?? "Other"
            category = (try? container.decode(String.self, forKey: .category)) ?? "Strength"
            cardioTracking = try? container.decodeIfPresent(String.self, forKey: .cardioTracking)
            sets = Self.flexibleInt(container, .sets) ?? 3
            reps = Self.flexibleInt(container, .reps) ?? 10
            note = try? container.decodeIfPresent(String.self, forKey: .note)
        }

        /// Accepts 3, "3", or "3-5" (takes the first number).
        private static func flexibleInt(
            _ container: KeyedDecodingContainer<CodingKeys>,
            _ key: CodingKeys
        ) -> Int? {
            if let value = try? container.decode(Int.self, forKey: key) { return value }
            if let value = try? container.decode(Double.self, forKey: key) { return Int(value) }
            if let text = try? container.decode(String.self, forKey: key) {
                let digits = text.prefix { $0.isNumber }
                if let value = Int(digits) { return value }
                // "8-12" style — fall back to scanning for the first run of digits
                if let firstRun = text.split(whereSeparator: { !$0.isNumber }).first {
                    return Int(firstRun)
                }
            }
            return nil
        }
    }
}
