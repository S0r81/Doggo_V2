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

// MARK: - Weight conversion (single source of truth)
//
// Weight is stored canonically in kilograms; only display crosses into pounds.
// These replace the magic 2.2046226 / 2.20462 / 0.453592 constants that were
// scattered — and subtly inconsistent — across a dozen views.

extension UnitSystem {
    /// 1 pound in kilograms — the exact international avoirdupois definition.
    static let kilogramsPerPound = 0.45359237
    /// 1 kilogram in pounds (≈ 2.2046226218).
    static let poundsPerKilogram = 1 / kilogramsPerPound

    /// Canonical kilograms → a value in this unit, for display.
    func displayWeight(fromKg kg: Double) -> Double {
        self == .imperial ? kg * Self.poundsPerKilogram : kg
    }

    /// A value entered in this unit → canonical kilograms, for storage.
    func kilograms(fromDisplay value: Double) -> Double {
        self == .imperial ? value * Self.kilogramsPerPound : value
    }

    /// "175.4 lbs" — display weight with its unit label.
    func formattedWeight(fromKg kg: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f %@", displayWeight(fromKg: kg), weightLabel)
    }
}

