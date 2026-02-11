//
//  WeeklyPlan.swift
//  Doggo_V2
//
//  Created by Sorest on 2/4/26.
//


//
//  WeeklyPlan.swift
//  Doggo_V2
//

import Foundation

struct WeeklyPlan: Codable {
    let weekFocus: String
    let days: [DaySchedule]
}

struct DaySchedule: Codable, Identifiable {
    var id: String { day }
    let day: String
    let focus: String
    let description: String
}