//
//  AIGeneratedRoutine.swift
//  Doggo
//
//  Created by Sorest on 1/14/26.
//

import Foundation
import SwiftData

@Model
class AIGeneratedRoutine {
    var id: UUID
    var date: Date
    var focus: String
    var duration: Int
    var routineName: String
    
    // We store the raw items as a lightweight struct-like array
    // Since SwiftData can't store complex structs easily, we will store a JSON string
    // or a relationship. For simplicity/robustness, we'll store the raw JSON string returned by Gemini.
    var rawJSON: String
    
    init(focus: String, duration: Int, routineName: String, rawJSON: String) {
        self.id = UUID()
        self.date = Date()
        self.focus = focus
        self.duration = duration
        self.routineName = routineName
        self.rawJSON = rawJSON
    }
}

