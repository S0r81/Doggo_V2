//
//  NutritionProfile.swift
//  Doggo_V2
//
//  The user's active diet plan: current calorie/macro targets, the phase of
//  the diet, and a rolling history of weekly check-ins. Phase is a String-backed
//  enum column (migration-safe, same pattern as CardioTrackingType /
//  PeptideFrequency) — a type tag, not a class hierarchy.
//
//  The profile also snapshots the questionnaire inputs (bf%, sex, age,
//  activity, protein, training) so the state machine can re-derive maintenance
//  and re-prescribe a deficit at the user's current weight after a diet break.
//

import Foundation
import SwiftData

/// Which stage of the long-term diet the user is currently in.
enum NutritionPhase: String, Codable, CaseIterable, Sendable, Identifiable {
    case deficit       // actively losing
    case dietBreak     // planned ~2 weeks at maintenance to blunt adaptation
    case reverseDiet   // gradual ramp back up post-diet to avoid fat overshoot
    case maintenance   // holding

    var id: String { rawValue }

    var label: String {
        switch self {
        case .deficit: return "In Deficit"
        case .dietBreak: return "Diet Break"
        case .reverseDiet: return "Reverse Dieting"
        case .maintenance: return "Maintenance"
        }
    }

    var icon: String {
        switch self {
        case .deficit: return "arrow.down.right.circle.fill"
        case .dietBreak: return "pause.circle.fill"
        case .reverseDiet: return "arrow.up.right.circle.fill"
        case .maintenance: return "equal.circle.fill"
        }
    }
}

@Model
final class NutritionProfile {
    var id: UUID
    var createdAt: Date

    // Diet targets
    var startingWeightKg: Double
    var goalWeightKg: Double
    var targetLossRate: Double

    // Input snapshot (for re-deriving maintenance / re-prescribing at new weights)
    var bodyFatPercent: Double
    var sexRaw: String
    var ageYears: Int
    var activityRaw: String
    var proteinPrefRaw: String
    var resistanceTraining: Bool

    // Current prescription
    var maintenanceCalories: Double
    var currentDailyCalories: Double
    var dailyDeficitKcal: Double
    var proteinTargetGrams: Double
    var carbTargetGrams: Double
    var fatTargetGrams: Double

    // Phase
    var phaseRaw: String
    var phaseStartedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \NutritionCheckIn.profile)
    var checkIns: [NutritionCheckIn] = []

    @Relationship(deleteRule: .cascade, inverse: \DailyMacroLog.profile)
    var dailyLogs: [DailyMacroLog] = []

    init(
        startingWeightKg: Double,
        goalWeightKg: Double,
        targetLossRate: Double,
        bodyFatPercent: Double,
        sex: BiologicalSex,
        ageYears: Int,
        activity: ActivityLevel,
        proteinPreference: ProteinPreference,
        resistanceTraining: Bool,
        maintenanceCalories: Double,
        currentDailyCalories: Double,
        dailyDeficitKcal: Double,
        proteinTargetGrams: Double,
        carbTargetGrams: Double,
        fatTargetGrams: Double,
        phase: NutritionPhase = .deficit
    ) {
        self.id = UUID()
        self.createdAt = Date()
        self.startingWeightKg = startingWeightKg
        self.goalWeightKg = goalWeightKg
        self.targetLossRate = targetLossRate
        self.bodyFatPercent = bodyFatPercent
        self.sexRaw = sex.rawValue
        self.ageYears = ageYears
        self.activityRaw = activity.rawValue
        self.proteinPrefRaw = proteinPreference.rawValue
        self.resistanceTraining = resistanceTraining
        self.maintenanceCalories = maintenanceCalories
        self.currentDailyCalories = currentDailyCalories
        self.dailyDeficitKcal = dailyDeficitKcal
        self.proteinTargetGrams = proteinTargetGrams
        self.carbTargetGrams = carbTargetGrams
        self.fatTargetGrams = fatTargetGrams
        self.phaseRaw = phase.rawValue
        self.phaseStartedAt = Date()
    }
}

extension NutritionProfile {
    var phase: NutritionPhase {
        get { NutritionPhase(rawValue: phaseRaw) ?? .deficit }
        set { phaseRaw = newValue.rawValue }
    }
    var sex: BiologicalSex {
        get { BiologicalSex(rawValue: sexRaw) ?? .male }
        set { sexRaw = newValue.rawValue }
    }
    var activity: ActivityLevel {
        get { ActivityLevel(rawValue: activityRaw) ?? .moderate }
        set { activityRaw = newValue.rawValue }
    }
    var proteinPreference: ProteinPreference {
        get { ProteinPreference(rawValue: proteinPrefRaw) ?? .high }
        set { proteinPrefRaw = newValue.rawValue }
    }

    /// Most recent rolling-average weight, falling back to the start weight.
    var latestWeightKg: Double {
        checkIns.max(by: { $0.date < $1.date })?.rollingAverageWeight ?? startingWeightKg
    }

    /// True once the user has reached (or passed) their goal weight.
    var hasReachedGoal: Bool {
        goalWeightKg > 0 && latestWeightKg <= goalWeightKg
    }

    /// Today's consumption row, if one exists yet.
    func todaysLog(calendar: Calendar = .current) -> DailyMacroLog? {
        let today = calendar.startOfDay(for: Date())
        return dailyLogs.first { calendar.isDate($0.date, inSameDayAs: today) }
    }
}
