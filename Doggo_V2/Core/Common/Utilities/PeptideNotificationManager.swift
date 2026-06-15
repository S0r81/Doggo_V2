//
//  PeptideNotificationManager.swift
//  Doggo_V2
//
//  Schedules local dose reminders from peptide schedules. Reminder plans are
//  built on the main actor from SwiftData models, then handed to the manager
//  as Sendable value snapshots — no model ever crosses into the notification
//  layer. Every request this manager owns is tagged with a "peptide-" id
//  prefix so a full re-sync can wipe and rebuild cleanly.
//
//  Trigger strategy by frequency:
//    · daily         → one repeating calendar trigger at the reminder time
//    · specificDays  → one repeating trigger per chosen weekday
//    · cycle         → concrete one-shot triggers for the next N due dates
//                      (an X-on/Y-off pattern can't be a single repeat rule)
//

import Foundation
import UserNotifications

/// Sendable snapshot of one peptide's reminder needs.
struct PeptideReminderPlan: Sendable {
    let profileID: UUID
    let peptideName: String
    /// e.g. "Pull to 10 units" — nil when the vial isn't fully configured.
    let pullHint: String?
    let hour: Int
    let minute: Int
    let frequency: PeptideFrequency
    /// Calendar weekday numbers (1 = Sunday … 7 = Saturday) for `.specificDays`.
    let weekdayNumbers: [Int]
    /// Concrete upcoming fire dates for `.cycle`.
    let cycleDates: [Date]

    /// Builds a plan from a profile. Main-actor isolated because it reads the
    /// SwiftData model; returns nil when the profile shouldn't remind.
    @MainActor
    static func make(from profile: PeptideProfile) -> PeptideReminderPlan? {
        guard profile.isActive,
              let schedule = profile.schedule,
              schedule.remindersEnabled else { return nil }

        var pullHint: String?
        if let calc = profile.calculation, calc.isValid {
            pullHint = "Pull to \(calc.roundedUnits) units"
        }

        let weekdayNumbers = schedule.specificWeekdays.compactMap {
            PeptideNotificationManager.weekdayNumber(for: $0)
        }
        let cycleDates = schedule.frequency == .cycle
            ? schedule.upcomingDueDates(count: 12)
            : []

        return PeptideReminderPlan(
            profileID: profile.id,
            peptideName: profile.name,
            pullHint: pullHint,
            hour: schedule.reminderHour,
            minute: schedule.reminderMinute,
            frequency: schedule.frequency,
            weekdayNumbers: weekdayNumbers,
            cycleDates: cycleDates
        )
    }
}

final class PeptideNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = PeptideNotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let idPrefix = "peptide-"

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    // MARK: - Sync

    /// Replaces every peptide reminder with a fresh set built from `plans`.
    func sync(plans: [PeptideReminderPlan]) async {
        // 1. Clear out our previously-scheduled reminders.
        let pending = await center.pendingNotificationRequests()
        let ourIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        if !ourIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: ourIDs)
        }

        guard !plans.isEmpty else { return }

        // 2. Make sure we're allowed to post.
        var status = await authorizationStatus()
        if status == .notDetermined {
            _ = await requestAuthorization()
            status = await authorizationStatus()
        }
        guard status == .authorized || status == .provisional else { return }

        // 3. Schedule each plan.
        for plan in plans {
            await schedule(plan)
        }
    }

    /// Convenience: clear everything (e.g. all reminders turned off).
    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ourIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ourIDs)
    }

    // MARK: - Scheduling

    private func schedule(_ plan: PeptideReminderPlan) async {
        let content = UNMutableNotificationContent()
        content.title = "Peptide Reminder"
        content.body = plan.pullHint.map { "Time for your \(plan.peptideName) dose — \($0)." }
            ?? "Time for your \(plan.peptideName) dose."
        content.sound = .default

        let base = "\(idPrefix)\(plan.profileID.uuidString)"
        var time = DateComponents()
        time.hour = plan.hour
        time.minute = plan.minute

        switch plan.frequency {
        case .daily:
            await add(id: "\(base)-daily", content: content,
                      trigger: UNCalendarNotificationTrigger(dateMatching: time, repeats: true))

        case .specificDays:
            for weekday in plan.weekdayNumbers {
                var comps = time
                comps.weekday = weekday
                await add(id: "\(base)-wd\(weekday)", content: content,
                          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: true))
            }

        case .cycle:
            let calendar = Calendar.current
            for (index, date) in plan.cycleDates.enumerated() {
                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                await add(id: "\(base)-cycle\(index)", content: content,
                          trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
            }
        }
    }

    private func add(id: String, content: UNNotificationContent, trigger: UNNotificationTrigger) async {
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    // MARK: - Weekday mapping

    /// "Monday" → 2, matching Calendar's 1=Sunday…7=Saturday convention.
    static func weekdayNumber(for name: String) -> Int? {
        switch name.lowercased() {
        case "sunday": return 1
        case "monday": return 2
        case "tuesday": return 3
        case "wednesday": return 4
        case "thursday": return 5
        case "friday": return 6
        case "saturday": return 7
        default: return nil
        }
    }

    // MARK: - Foreground presentation

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }
}
