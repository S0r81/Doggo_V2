//
//  CoachContextItem.swift
//  Doggo_V2
//
//  One independently-editable fact the user wants the AI Coach to always know
//  ("What Coach knows"). Many items per category, one row each — so entries are
//  individually editable/deletable rather than one giant text blob.
//
//  Standalone model: NO relationships, so it carries zero cascade/orphan risk
//  and cannot participate in the dangling-reference class of crash.
//

import Foundation
import SwiftData

@Model
final class CoachContextItem {
    var id: UUID
    /// Backing string for `CoachContextCategory` (migration-safe — same pattern
    /// as CardioTrackingType / NutritionPhase: a type tag, not a class).
    var categoryRaw: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    /// Stable manual ordering within a category (lower = first).
    var sortOrder: Int

    init(category: CoachContextCategory, text: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.categoryRaw = category.rawValue
        self.text = text
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
        self.sortOrder = sortOrder
    }

    /// Typed access to the stored category string.
    var category: CoachContextCategory {
        get { CoachContextCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
}

/// The six fixed buckets the user can file context under. `nonisolated` so the
/// (off-main) prompt assembly can read it without hopping to the main actor.
nonisolated enum CoachContextCategory: String, CaseIterable, Identifiable, Codable {
    case dietary
    case injuries
    case equipment
    case schedule
    case goals
    case other

    var id: String { rawValue }

    /// UI section title.
    var label: String {
        switch self {
        case .dietary: return "Dietary"
        case .injuries: return "Injuries & Limits"
        case .equipment: return "Equipment"
        case .schedule: return "Schedule"
        case .goals: return "Personal Goals"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .dietary: return "fork.knife"
        case .injuries: return "bandage"
        case .equipment: return "dumbbell"
        case .schedule: return "calendar"
        case .goals: return "target"
        case .other: return "note.text"
        }
    }

    /// Inline placeholder shown in the editor's add/edit field.
    var placeholder: String {
        switch self {
        case .dietary: return "e.g. vegetarian, lactose intolerant"
        case .injuries: return "e.g. left knee — careful with squats"
        case .equipment: return "e.g. home gym, no barbell"
        case .schedule: return "e.g. can only train Mon/Wed/Fri mornings"
        case .goals: return "e.g. add 20 lb to my bench by spring"
        case .other: return "e.g. prefer short, intense sessions"
        }
    }

    /// Heading used for this category inside the assembled prompt block.
    var promptHeading: String {
        switch self {
        case .dietary: return "Dietary"
        case .injuries: return "Injuries & Limitations"
        case .equipment: return "Available Equipment"
        case .schedule: return "Schedule Constraints"
        case .goals: return "Personal Goals"
        case .other: return "Other Notes"
        }
    }
}
