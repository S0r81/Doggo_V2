//
//  DashboardViewModel.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Helper Structs
struct ExerciseStat: Identifiable {
    let id = UUID()
    let name: String
    let count: Int
}

struct BestLift: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let unit: String
    let date: Date
    let exercise: Exercise?
}

struct AnalyticsDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct WeeklyVolume: Identifiable {
    let id = UUID()
    let weekLabel: String
    let volume: Double
    let date: Date
}

// NEW: Wrapper for Paged Data
struct WeekPage: Identifiable {
    let id = UUID()
    let label: String // "Jan 13 - Jan 19"
    let days: [DashboardViewModel.DailyCount]
}

struct VolumePage: Identifiable {
    let id = UUID()
    let label: String // "Last 4 Weeks"
    let weeks: [WeeklyVolume]
}
struct ExerciseFocusItem: Identifiable {
        let id = UUID()
        let name: String
        let sets: Int
        let percent: Double // 0.0 to 1.0 relative to the top exercise
    }

@Observable
class DashboardViewModel {
    
    // Greeting
    var greetingMessage: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }
    
    // MARK: - Consistency Data (Paged)
    struct DailyCount: Identifiable {
        let id = UUID()
        let day: String  // "Mon"
        let count: Int
        let date: Date
    }
    
    // Returns an array of Pages (Weeks), strictly Mon-Sun
    func getConsistencyPages(from sessions: [WorkoutSession]) -> [WeekPage] {
        var pages: [WeekPage] = []
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        let today = Date()
        
        // Determine the start of the CURRENT week (Monday)
        // We use .yearForWeekOfYear to handle year boundaries correctly (e.g. Dec 30 - Jan 5)
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let currentWeekStart = calendar.date(from: components) else { return [] }
        
        // Generate last 5 weeks (Oldest -> Newest)
        // So the last element is "This Week"
        for i in (0..<5).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: currentWeekStart) else { continue }
            
            var days: [DailyCount] = []
            
            // Build 7 days for this week
            for j in 0..<7 {
                if let dayDate = calendar.date(byAdding: .day, value: j, to: weekStart) {
                    let count = sessions.filter { calendar.isDate($0.date, inSameDayAs: dayDate) }.count
                    
                    let formatter = DateFormatter()
                    formatter.dateFormat = "E"
                    let name = formatter.string(from: dayDate)
                    
                    days.append(DailyCount(day: name, count: count, date: dayDate))
                }
            }
            
            // Create Page Label
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: weekStart)!
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            let label = i == 0 ? "This Week" : "\(fmt.string(from: weekStart)) - \(fmt.string(from: endOfWeek))"
            
            pages.append(WeekPage(label: label, days: days))
        }
        return pages
    }
    
    // MARK: - Volume Data (Paged)
    // Returns Pages of 4 weeks each
    func getVolumePages(from sessions: [WorkoutSession]) -> [VolumePage] {
        var pages: [VolumePage] = []
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        
        let today = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        guard let currentWeekStart = calendar.date(from: components) else { return [] }
        
        // We want 3 pages of 4 weeks = 12 weeks total history
        // Page 0: Weeks 9-12 ago
        // Page 1: Weeks 5-8 ago
        // Page 2: Last 4 weeks (Current)
        
        for pageIndex in (0..<3).reversed() {
            var weeks: [WeeklyVolume] = []
            
            // Each page has 4 weeks.
            // Page 0 (Current) starts at offset 0
            // Page 1 starts at offset -4
            // Page 2 starts at offset -8
            let pageOffset = pageIndex * 4
            
            // Inside the page, we go from Oldest (-3) to Newest (0) relative to that block
            for w in (0..<4).reversed() {
                let weekOffset = -(pageOffset + w) // e.g. -3, -2, -1, 0 for first page
                
                if let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) {
                    let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
                    
                    let weekSessions = sessions.filter {
                        $0.date >= weekStart && $0.date < calendar.date(byAdding: .day, value: 1, to: weekEnd)!
                    }
                    
                    let vol = getTotalVolumeRaw(from: weekSessions)
                    let fmt = DateFormatter()
                    fmt.dateFormat = "MMM d"
                    
                    weeks.append(WeeklyVolume(weekLabel: fmt.string(from: weekStart), volume: vol, date: weekStart))
                }
            }
            
            let label: String
            if pageIndex == 0 {
                label = "Last 4 Weeks"
            } else if let first = weeks.first, let last = weeks.last {
                label = "\(first.weekLabel) – \(last.weekLabel)"
            } else {
                label = "History"
            }
            pages.append(VolumePage(label: label, weeks: weeks))
        }
        
        return pages
    }
    
    // ... (Keep existing stats methods: Duration, Streak, Top Exercises, Bests, 1RM) ...
    
    func getTotalDuration(from sessions: [WorkoutSession]) -> String {
        let total = sessions.reduce(0) { $0 + $1.duration }
        return String(format: "%.1f hrs", total / 3600)
    }
    
    func getCurrentStreak(from sessions: [WorkoutSession]) -> Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        let sorted = uniqueDays.sorted(by: >)
        guard let last = sorted.first else { return 0 }
        
        let today = calendar.startOfDay(for: Date())
        let yest = calendar.date(byAdding: .day, value: -1, to: today)!
        
        if last != today && last != yest { return 0 }
        
        var streak = 0
        var check = last
        for day in sorted {
            if calendar.isDate(day, inSameDayAs: check) {
                streak += 1
                check = calendar.date(byAdding: .day, value: -1, to: check)!
            } else { break }
        }
        return streak
    }
    
    func getTotalVolume(from sessions: [WorkoutSession], preferredUnit: String) -> String {
        let raw = getTotalVolumeRaw(from: sessions)
        let val = (preferredUnit == "metric" || preferredUnit == "kg") ? raw * 0.453592 : raw
        let suffix = (preferredUnit == "metric" || preferredUnit == "kg") ? "kg" : "lbs"
        
        if val > 1_000_000 { return String(format: "%.1fM %@", val/1_000_000, suffix) }
        else if val > 1_000 { return String(format: "%.1fk %@", val/1_000, suffix) }
        else { return "\(Int(val)) \(suffix)" }
    }
    
    private func getTotalVolumeRaw(from sessions: [WorkoutSession]) -> Double {
        var total: Double = 0
        for s in sessions {
            for set in s.sets {
                // Cardio never contributes to weight volume. (The old
                // `distance == nil` check was unreliable — strength sets
                // initialize distance to 0.0, not nil.)
                guard set.exercise?.isCardio != true else { continue }
                var w = set.weight
                if set.unit == "kg" { w *= 2.20462 }
                total += (w * Double(set.reps))
            }
        }
        return total
    }
    
    func getTopExercises(from sessions: [WorkoutSession]) -> [ExerciseStat] {
        var counts: [String: Int] = [:]
        for s in sessions {
            for set in s.sets {
                if let m = set.exercise?.muscleGroup { counts[m, default: 0] += 1 }
                else if let n = set.exercise?.name { counts[n, default: 0] += 1 }
            }
        }
        return counts.map { ExerciseStat(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
            .prefix(5).map { $0 }
    }
    
    func getRecentBests(from sessions: [WorkoutSession]) -> [BestLift] {
        var bests: [String: BestLift] = [:]
        for s in sessions.prefix(15) {
            for set in s.sets {
                guard let ex = set.exercise, set.weight > 0 else { continue }
                if let curr = bests[ex.name] {
                    if set.weight > curr.weight {
                        bests[ex.name] = BestLift(exerciseName: ex.name, weight: set.weight, unit: set.unit, date: s.date, exercise: ex)
                    }
                } else {
                    bests[ex.name] = BestLift(exerciseName: ex.name, weight: set.weight, unit: set.unit, date: s.date, exercise: ex)
                }
            }
        }
        return bests.values.sorted { $0.weight > $1.weight }.prefix(5).map { $0 }
    }
    
    func getWeeklyTopExercises(from sessions: [WorkoutSession]) -> [ExerciseFocusItem] {
            let calendar = Calendar.current
            let now = Date()
            guard let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else { return [] }
            
            let weeklySessions = sessions.filter { $0.date >= startOfWeek }
            
            var counts: [String: Int] = [:]
            for session in weeklySessions {
                for set in session.sets {
                    if let name = set.exercise?.name {
                        counts[name, default: 0] += 1
                    }
                }
            }
            
            let sorted = counts.sorted { $0.value > $1.value }
            let maxSets = Double(sorted.first?.value ?? 1)
            
            return sorted.prefix(3).map {
                ExerciseFocusItem(name: $0.key, sets: $0.value, percent: Double($0.value) / maxSets)
            }
        }
}

