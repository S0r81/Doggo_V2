//
//  PeptideCalendarView.swift
//  Doggo_V2
//
//  A custom month-grid calendar (no third-party packages) that merges past and
//  future at a glance:
//    · a filled green dot under days with a logged injection
//    · a hollow accent dot under future days a dose is scheduled
//  Prev/Next chevrons shift the visible month. Pure 7-column LazyVGrid.
//

import SwiftUI
import SwiftData

struct PeptideCalendarView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @Query(sort: \PeptideLog.date) private var logs: [PeptideLog]
    @Query private var profiles: [PeptideProfile]

    @State private var monthAnchor = Date()

    private var accent: Color { Color.accent(for: userTheme) }
    private var calendar: Calendar { Calendar.current }

    // MARK: - Month geometry

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: monthAnchor)) ?? monthAnchor
    }

    private var daysInMonth: Int {
        calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    /// Empty cells before day 1 so the first day lands under its weekday.
    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: monthStart)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: monthStart)
    }

    /// Weekday header letters, ordered to the locale's first weekday.
    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    // MARK: - Indicator data

    /// Start-of-day for every logged injection (fast membership test).
    private var loggedDays: Set<Date> {
        Set(logs.map { calendar.startOfDay(for: $0.date) })
    }

    private var activeSchedules: [PeptideSchedule] {
        profiles.compactMap { profile in
            guard profile.isActive, let schedule = profile.schedule,
                  schedule.targetDoseMcg > 0 else { return nil }
            return schedule
        }
    }

    private func isLogged(_ day: Date) -> Bool {
        loggedDays.contains(calendar.startOfDay(for: day))
    }

    /// Scheduled but not yet today/past — the "upcoming" hollow dot.
    private func isScheduledFuture(_ day: Date) -> Bool {
        let today = calendar.startOfDay(for: Date())
        guard calendar.startOfDay(for: day) >= today else { return false }
        return activeSchedules.contains { $0.isDoseDue(on: day, calendar: calendar) }
    }

    private func date(forDay day: Int) -> Date {
        calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: Spacing.md) {
            header
            weekdayHeader
            grid
            legend
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private var header: some View {
        HStack {
            chevron("chevron.left", delta: -1)
            Spacer()
            Text(monthTitle)
                .font(.headline)
                .contentTransition(.numericText())
            Spacer()
            chevron("chevron.right", delta: 1)
        }
    }

    private func chevron(_ symbol: String, delta: Int) -> some View {
        Button {
            withAnimation(.snappy) {
                monthAnchor = calendar.date(byAdding: .month, value: delta, to: monthStart) ?? monthStart
            }
            HapticManager.shared.impact(style: .light)
        } label: {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var grid: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return LazyVGrid(columns: columns, spacing: Spacing.sm) {
            ForEach(0..<leadingBlanks, id: \.self) { _ in
                Color.clear.frame(height: 40)
            }
            ForEach(1...daysInMonth, id: \.self) { day in
                dayCell(day)
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let cellDate = date(forDay: day)
        let isToday = calendar.isDateInToday(cellDate)
        let logged = isLogged(cellDate)
        let scheduled = !logged && isScheduledFuture(cellDate)

        return VStack(spacing: 3) {
            Text("\(day)")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isToday ? accent : .primary)
                .frame(width: 30, height: 30)
                .background {
                    if isToday {
                        Circle().fill(accent.opacity(0.15))
                    }
                }

            // Indicator dot (logged wins over scheduled).
            Group {
                if logged {
                    Circle().fill(Color.green).frame(width: 6, height: 6)
                } else if scheduled {
                    Circle().stroke(accent, lineWidth: 1.5).frame(width: 6, height: 6)
                } else {
                    Color.clear.frame(width: 6, height: 6)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 40)
    }

    private var legend: some View {
        HStack(spacing: Spacing.lg) {
            HStack(spacing: Spacing.xs) {
                Circle().fill(Color.green).frame(width: 6, height: 6)
                Text("Logged").font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: Spacing.xs) {
                Circle().stroke(accent, lineWidth: 1.5).frame(width: 6, height: 6)
                Text("Scheduled").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
