//
//  AppFormatters.swift
//  Doggo_V2
//
//  Cached, shared DateFormatters. `DateFormatter()` is expensive to create
//  (locale/calendar resolution), so these were being re-allocated on every
//  call site — some inside per-render view bodies. Reuse them instead.
//
//  Weekday formatting uses the POSIX locale on purpose: the app matches against
//  the English `weekdayNames` array, so a localized "Montag"/"lundi" would
//  silently fail to match on non-English devices.
//

import Foundation

enum AppFormatters {
    /// Full weekday name, English — "Monday". Safe to compare with `weekdayNames`.
    static let weekday = make("EEEE", posix: true)
    /// Short weekday — "Mon".
    static let weekdayShort = make("E")
    /// "Jun 14".
    static let monthDay = make("MMM d")
    /// "June 2026".
    static let monthYear = make("MMMM yyyy")

    private static func make(_ format: String, posix: Bool = false) -> DateFormatter {
        let formatter = DateFormatter()
        if posix { formatter.locale = Locale(identifier: "en_US_POSIX") }
        formatter.dateFormat = format
        return formatter
    }
}
