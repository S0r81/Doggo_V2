//
//  UnitSystem.swift
//  Doggo
//
//  Created by Sorest on 1/6/26.
//

import SwiftUI

enum UnitSystem: String, CaseIterable, Codable {
    case imperial
    case metric
    
    var weightLabel: String {
        self == .imperial ? "lbs" : "kg"
    }
    
    var distanceLabel: String {
        self == .imperial ? "mi" : "km"
    }
}

