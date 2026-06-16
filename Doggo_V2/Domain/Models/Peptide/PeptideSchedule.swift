//
//  PeptideSchedule.swift
//  Doggo_V2
//
//  When a peptide is due and at what dose. Frequency is stored as a String
//  (migration-safe, same pattern as CardioTrackingType) with a typed accessor.
//

import Foundation
import SwiftData

/// How often a dose is due.
enum PeptideFrequency: String, Codable, CaseIterable, Identifiable, Sendable {
    case daily = "Daily"
    case specificDays = "Specific Days"   // chosen weekdays
    case cycle = "Cycle"                  // X days on, Y days off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: return "Every Day"
        case .specificDays: return "Specific Days"
        case .cycle: return "Cycle (On / Off)"
        }
    }

    var icon: String {
        switch self {
        case .daily: return "calendar"
        case .specificDays: return "calendar.badge.clock"
        case .cycle: return "arrow.triangle.2.circlepath"
        }
    }
}

@Model
final class PeptideSchedule {
    var id: UUID
    /// Backing store for `frequency`.
    var frequencyRaw: String
    /// Target dose amount, expressed in `doseUnit` (the legacy `targetDoseMcg`
    /// name is kept for store stability; it may hold mcg, mg, or IU).
    var targetDoseMcg: Double
    /// Dose measurement unit ("mcg" / "mg" / "iu"). String-backed for migration
    /// safety; existing rows default to mcg. See `doseUnit` for the typed view.
    var doseUnitRaw: String = PeptideMeasurementUnit.mcg.rawValue

    /// `.specificDays` — full weekday names ("Monday"…), matching the app's
    /// `weekdayNames` convention.
    var specificWeekdays: [String]

    /// `.cycle` — e.g. 5 on / 2 off, counted from `anchorDate`.
    var daysOn: Int
    var daysOff: Int
    /// Day-zero reference for cycle math (and the schedule's start).
    var anchorDate: Date

    /// Local time of the daily reminder.
    var reminderHour: Int
    var reminderMinute: Int
    var remindersEnabled: Bool

    var profile: PeptideProfile?

    init(
        frequency: PeptideFrequency = .daily,
        targetDoseMcg: Double = 0,
        doseUnit: PeptideMeasurementUnit = .mcg,
        specificWeekdays: [String] = [],
        daysOn: Int = 5,
        daysOff: Int = 2,
        anchorDate: Date = Date(),
        reminderHour: Int = 8,
        reminderMinute: Int = 0,
        remindersEnabled: Bool = true
    ) {
        self.id = UUID()
        self.frequencyRaw = frequency.rawValue
        self.targetDoseMcg = targetDoseMcg
        self.doseUnitRaw = doseUnit.rawValue
        self.specificWeekdays = specificWeekdays
        self.daysOn = daysOn
        self.daysOff = daysOff
        self.anchorDate = anchorDate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.remindersEnabled = remindersEnabled
    }
}

extension PeptideSchedule {
    /// Typed view over the stored frequency string.
    var frequency: PeptideFrequency {
        get { PeptideFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    /// Typed view over the stored dose unit.
    var doseUnit: PeptideMeasurementUnit {
        get { PeptideMeasurementUnit(rawValue: doseUnitRaw) ?? .mcg }
        set { doseUnitRaw = newValue.rawValue }
    }

    /// The reminder time as date components (for UNCalendarNotificationTrigger).
    var reminderTimeComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }

    /// Whether a dose falls on the given calendar day. Pure — no fetch.
    func isDoseDue(on date: Date, calendar: Calendar = .current) -> Bool {
        switch frequency {
        case .daily:
            return true

        case .specificDays:
            guard !specificWeekdays.isEmpty else { return false }
            return specificWeekdays.contains(Self.weekdayName(for: date, calendar: calendar))

        case .cycle:
            let period = daysOn + daysOff
            guard period > 0, daysOn > 0 else { return false }
            let start = calendar.startOfDay(for: anchorDate)
            let day = calendar.startOfDay(for: date)
            let delta = calendar.dateComponents([.day], from: start, to: day).day ?? -1
            guard delta >= 0 else { return false }
            return (delta % period) < daysOn
        }
    }

    /// The next `count` upcoming due dates at the reminder time, starting from
    /// `date`. Used by the dashboard timeline and the notification scheduler.
    func upcomingDueDates(from date: Date = Date(), count: Int = 14, calendar: Calendar = .current) -> [Date] {
        var results: [Date] = []
        var cursor = calendar.startOfDay(for: date)
        var scanned = 0
        // Scan a bounded window so a misconfigured schedule can't loop forever.
        while results.count < count && scanned < count * 4 + 60 {
            if isDoseDue(on: cursor, calendar: calendar),
               let fireDate = calendar.date(
                   bySettingHour: reminderHour,
                   minute: reminderMinute,
                   second: 0,
                   of: cursor
               ),
               fireDate >= date {
                results.append(fireDate)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
            scanned += 1
        }
        return results
    }

    static func weekdayName(for date: Date, calendar: Calendar) -> String {
        return AppFormatters.weekday.string(from: date)
    }
}
