//
//  CardioFormatter.swift
//  Doggo_V2
//
//  One place to turn a cardio session set into clean display text — history,
//  summaries, and analytics all show "30:00 • 3.2 mi" / "30:00 • 40 laps",
//  never "1 set".
//

import Foundation

enum CardioFormatter {

    /// "30:00 • 3.2 mi" · "25:00 • 3,000 steps" · "45:00 • 12 floors" ·
    /// "30:00 • 40 laps" · "30:00" (time only) · "No data"
    static func summary(for set: WorkoutSet?) -> String {
        guard let set else { return "—" }

        let tracking = set.exercise?.cardioTracking ?? legacyTracking(for: set)
        var parts: [String] = []

        if let minutes = set.duration, minutes > 0 {
            parts.append(clock(minutes))
        }

        switch tracking {
        case .distance:
            if let distance = set.distance, distance > 0 {
                let unit = ["mi", "km"].contains(set.unit.lowercased()) ? set.unit : "mi"
                parts.append("\(distance.formatted()) \(unit)")
            }
        case .steps, .floors, .laps:
            if let count = set.steps, count > 0 {
                parts.append("\(count.formatted()) \(tracking.countUnit ?? "")")
            }
        case .timeOnly:
            break // the clock is the whole story
        }

        return parts.isEmpty ? "No data" : parts.joined(separator: " • ")
    }

    /// 30.5 minutes → "30:30"
    static func clock(_ minutes: Double) -> String {
        let totalSeconds = Int((minutes * 60).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    /// When the exercise is gone (deleted), sniff the tracking type from the
    /// set's own data so old history still formats correctly.
    private static func legacyTracking(for set: WorkoutSet) -> CardioTrackingType {
        CardioTrackingType.inferred(fromUnit: set.unit, hasDistance: (set.distance ?? 0) > 0)
    }
}
