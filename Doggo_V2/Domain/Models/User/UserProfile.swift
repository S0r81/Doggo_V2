//
//  UserProfile.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import Foundation
import SwiftData

// (Keep WorkoutSplit Enum here...)
enum WorkoutSplit: String, CaseIterable, Codable {
    case pushPullLegs = "Push / Pull / Legs"
    case upperLower = "Upper / Lower"
    case fullBody = "Full Body"
    case broSplit = "Body Part (Bro Split)"
    case hybrid = "Hybrid (Lift + Cardio)"
    case flexible = "Flexible / AI Decides"
    
    var description: String {
        switch self {
        case .pushPullLegs: return "Training movements (Pushing vs Pulling) rather than body parts. 3-6 days/week."
        case .upperLower: return "Splitting the body into Upper and Lower halves. 4 days/week."
        case .fullBody: return "Hitting the entire body every session. 2-3 days/week."
        case .broSplit: return "Focusing on one major muscle group per day. 5 days/week."
        case .hybrid: return "Balancing strength training with running or sports."
        case .flexible: return "No set structure. I train what feels fresh."
        }
    }
    
    var pros: String {
        switch self {
        case .pushPullLegs: return "✅ Excellent muscle balance & recovery logic.\n✅ High volume capacity."
        case .upperLower: return "✅ Great for strength gains.\n✅ Easy to schedule rest days."
        case .fullBody: return "✅ Highest frequency (hitting muscles 3x/week).\n✅ Most time-efficient."
        case .broSplit: return "✅ Maximum focus on specific muscles.\n✅ Shorter, less draining workouts."
        case .hybrid: return "✅ Builds well-rounded athleticism.\n✅ Improves heart health & endurance."
        case .flexible: return "✅ Zero pressure.\n✅ Adaptable to busy lives."
        }
    }
    
    var cons: String {
        switch self {
        case .pushPullLegs: return "⚠️ Requires 6 days/week for max benefit.\n⚠️ Can lead to systemic fatigue."
        case .upperLower: return "⚠️ Upper body days can take a long time.\n⚠️ Less 'pump' focus."
        case .fullBody: return "⚠️ Hard to specialize on weak points.\n⚠️ Heavy fatigue per session."
        case .broSplit: return "⚠️ Low frequency (1x/week).\n⚠️ Miss a day? You wait a whole week."
        case .hybrid: return "⚠️ Slower strength gains vs. pure lifting.\n⚠️ Recovery management is tricky."
        case .flexible: return "⚠️ Harder to track progressive overload.\n⚠️ Inconsistent results."
        }
    }
}

@Model
class UserProfile {
    var name: String
    var age: Int
    var heightCM: Double
    var weightKG: Double
    var activityLevel: String
    var fitnessGoal: String
    var experienceLevel: String
    
    var splitPreference: String = "Flexible / AI Decides"
    
    // NEW: Integration Toggles
    var useCoachForSchedule: Bool = true
    var useCoachForRoutine: Bool = true
    
    var useMetric: Bool = false
    
    // NEW: The Weekly Schedule
    // Key: Day Name (e.g. "Monday"), Value: Routine UUID string
    var weeklySchedule: [String: String] = [:]
    
    init(name: String, age: Int, heightCM: Double, weightKG: Double, activityLevel: String, fitnessGoal: String, experienceLevel: String, splitPreference: String = "Flexible / AI Decides") {
        self.name = name
        self.age = age
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.activityLevel = activityLevel
        self.fitnessGoal = fitnessGoal
        self.experienceLevel = experienceLevel
        self.splitPreference = splitPreference
        
        // Defaults
        self.useCoachForSchedule = true
        self.useCoachForRoutine = true
        self.weeklySchedule = [:]
    }
    
    var preferredSplit: WorkoutSplit {
        return WorkoutSplit(rawValue: splitPreference) ?? .flexible
    }
    
    var aiDescription: String {
        return """
        USER PROFILE:
        - Name: \(name)
        - Age: \(age)
        - Stats: \(Int(heightCM))cm, \(Int(weightKG))kg
        - Level: \(experienceLevel)
        - Activity: \(activityLevel)
        - PRIMARY GOAL: \(fitnessGoal)
        - PREFERRED SPLIT: \(splitPreference)
        """
    }
}

