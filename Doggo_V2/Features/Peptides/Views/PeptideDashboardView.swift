//
//  PeptideDashboardView.swift
//  Doggo_V2
//
//  The Peptides tab: a calculator, upcoming dose timeline, per-peptide cards,
//  and a swipe-to-delete injection history.
//
//  Display reads live via @Query on the main context. Every mutation routes
//  through the @ModelActor PeptideRepository using the model's
//  persistentModelID, so background-context models never enter a relationship.
//

import SwiftUI
import SwiftData

struct PeptideDashboardView: View {
    let container: AppContainer

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userTheme") private var userTheme: AppTheme = .light

    @Query(sort: \PeptideProfile.createdAt, order: .reverse)
    private var profiles: [PeptideProfile]
    @Query(sort: \PeptideLog.date, order: .reverse)
    private var logs: [PeptideLog]

    @State private var showCalculator = false
    @State private var editingProfile: PeptideProfile?
    @State private var showNewProfile = false

    private var accent: Color { Color.accent(for: userTheme) }
    private var activeProfiles: [PeptideProfile] { profiles.filter { $0.isActive } }

    // MARK: - Upcoming dose events

    private struct DoseEvent: Identifiable {
        let id = UUID()
        let profile: PeptideProfile
        let date: Date
    }

    private var upcomingEvents: [DoseEvent] {
        let now = Date()
        var events: [DoseEvent] = []
        for profile in activeProfiles {
            guard let schedule = profile.schedule, schedule.targetDoseMcg > 0 else { continue }
            for date in schedule.upcomingDueDates(from: now, count: 3) {
                events.append(DoseEvent(profile: profile, date: date))
            }
        }
        return events.sorted { $0.date < $1.date }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                if profiles.isEmpty {
                    emptyState
                        .padding(.top, 80)
                } else {
                    VStack(spacing: Spacing.xl) {
                        PeptideCalendarView()
                            .padding(.horizontal)
                        if !upcomingEvents.isEmpty { upcomingSection }
                        peptidesSection
                        if !logs.isEmpty { historySection }
                    }
                    .padding(.vertical, Spacing.lg)
                }
            }
            .navigationTitle("Peptides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalculator = true
                    } label: {
                        Image(systemName: "function")
                    }
                    .accessibilityLabel("Reconstitution calculator")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProfile = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add peptide")
                }
            }
            .sheet(isPresented: $showCalculator) {
                PeptideCalculatorView()
            }
            .sheet(isPresented: $showNewProfile) {
                PeptideEditorView(container: container, profileToEdit: nil, onSaved: syncReminders)
            }
            .sheet(item: $editingProfile) { profile in
                PeptideEditorView(container: container, profileToEdit: profile, onSaved: syncReminders)
            }
            .task { syncReminders() }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "syringe")
                .font(.system(size: 56))
                .foregroundStyle(accent)
            Text("Track Your Peptides")
                .font(.title2.bold())
            Text("Add a peptide to calculate your dose, get reminders, and log every injection.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)

            Button {
                showNewProfile = true
            } label: {
                Label("Add Peptide", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.borderedProminent)
            .tint(accent)

            Button {
                showCalculator = true
            } label: {
                Label("Just the Calculator", systemImage: "function")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - Upcoming

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Upcoming Doses", icon: "clock")
            VStack(spacing: Spacing.sm) {
                ForEach(upcomingEvents) { event in
                    upcomingRow(event)
                }
            }
            .padding(.horizontal)
        }
    }

    private func upcomingRow(_ event: DoseEvent) -> some View {
        let dose = event.profile.schedule?.targetDoseMcg ?? 0
        let logged = isLogged(event.profile, on: event.date)
        return HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.profile.name)
                    .font(.subheadline.weight(.semibold))
                Text(relativeLabel(for: event.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let units = event.profile.calculation?.roundedUnits {
                Text("\(units) u")
                    .font(.caption.bold())
                    .foregroundStyle(accent)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 4)
                    .background(accent.opacity(0.12), in: Capsule())
            }
            if logged {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button {
                    logDose(event.profile, dose: dose, date: event.date)
                } label: {
                    Text("Log")
                        .font(.caption.bold())
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 6)
                        .background(accent, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.md)
        .cardSurface()
    }

    // MARK: - Peptides

    private var peptidesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Your Peptides", icon: "cross.vial")
            VStack(spacing: Spacing.sm) {
                ForEach(profiles) { profile in
                    Button {
                        editingProfile = profile
                    } label: {
                        peptideCard(profile)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    private func peptideCard(_ profile: PeptideProfile) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                if !profile.isActive {
                    Text("PAUSED")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let units = profile.calculation?.roundedUnits {
                    Text("Pull \(units) u")
                        .font(.subheadline.bold())
                        .foregroundStyle(accent)
                }
            }

            Text("\(PeptideCalculator.format(profile.totalMg)) \(profile.vialUnit.label) in \(PeptideCalculator.format(profile.waterAddedMl)) ml")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let schedule = profile.schedule {
                Label(scheduleSummary(schedule), systemImage: schedule.frequency.icon)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let calc = profile.calculation, calc.isValid {
                SyringeVisual(units: min(calc.unitsToPull, 100), accent: accent)
                    .padding(.top, Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .cardSurface()
    }

    // MARK: - History

    private var historySection: some View {
        let shown = Array(logs.prefix(40))
        // A scroll-disabled, fixed-height List nested in the card dashboard:
        // keeps the card aesthetic up top while giving History native
        // swipe-to-delete.
        return VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("History", icon: "list.bullet.clipboard")
            List {
                ForEach(shown) { log in
                    historyRow(log)
                        .listRowInsets(EdgeInsets(top: Spacing.sm, leading: Spacing.lg,
                                                  bottom: Spacing.sm, trailing: Spacing.lg))
                        .listRowBackground(Color.cardSurface(for: userTheme))
                        .listRowSeparator(.hidden)
                }
                .onDelete { offsets in
                    for index in offsets { deleteLog(shown[index]) }
                }
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(shown.count) * 60 + 4)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
        }
    }

    private func historyRow(_ log: PeptideLog) -> some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.profile?.name ?? "Peptide")
                    .font(.subheadline.weight(.medium))
                Text(log.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(PeptideCalculator.format(log.doseTakenMcg)) \(log.doseUnit.label)")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Helpers

    private func scheduleSummary(_ schedule: PeptideSchedule) -> String {
        let time = String(format: "%02d:%02d", schedule.reminderHour, schedule.reminderMinute)
        switch schedule.frequency {
        case .daily:
            return "Daily at \(time)"
        case .specificDays:
            let days = schedule.specificWeekdays.map { String($0.prefix(3)) }.joined(separator: ", ")
            return days.isEmpty ? "No days set" : days
        case .cycle:
            return "\(schedule.daysOn) on / \(schedule.daysOff) off"
        }
    }

    private func relativeLabel(for date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return "Today · \(time)" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow · \(time)" }
        return date.formatted(.dateTime.weekday(.wide)) + " · \(time)"
    }

    private func isLogged(_ profile: PeptideProfile, on date: Date) -> Bool {
        let calendar = Calendar.current
        return logs.contains { log in
            log.profile?.id == profile.id && calendar.isDate(log.date, inSameDayAs: date)
        }
    }

    // MARK: - Mutations (via repository)

    private func logDose(_ profile: PeptideProfile, dose: Double, date: Date) {
        // Log against "now" but attributed to the scheduled day for the
        // already-logged check (use the dose day's start + current time feel).
        let stamp = Calendar.current.isDateInToday(date) ? Date() : date
        let id = profile.persistentModelID
        let unit = profile.schedule?.doseUnit ?? .mcg
        Task {
            _ = try? await container.peptideRepository.logDose(profileID: id, doseMcg: dose, doseUnit: unit, date: stamp, note: nil)
            await MainActor.run { HapticManager.shared.notification(type: .success) }
        }
    }

    private func deleteLog(_ log: PeptideLog) {
        let id = log.persistentModelID
        Task {
            try? await container.peptideRepository.deleteLog(id: id)
            await MainActor.run { HapticManager.shared.impact(style: .light) }
        }
    }

    /// Rebuilds all local reminders from the current profiles (read on main).
    private func syncReminders() {
        let fresh = (try? modelContext.fetch(FetchDescriptor<PeptideProfile>())) ?? profiles
        let plans = fresh.compactMap { PeptideReminderPlan.make(from: $0) }
        Task { await PeptideNotificationManager.shared.sync(plans: plans) }
    }
}
