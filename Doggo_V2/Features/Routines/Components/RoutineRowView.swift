//
//  RoutineRowView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

// MARK: - Shared Helpers

/// Rough session length: ~40s of work per set plus the user's rest interval.
func estimatedMinutes(for routine: Routine, restSeconds: Int) -> Int {
    let totalSets = routine.items.reduce(0) { $0 + max(1, $1.templateSets.count) }
    guard totalSets > 0 else { return 0 }
    let seconds = Double(totalSets) * (40.0 + Double(restSeconds))
    return max(5, Int((seconds / 60.0).rounded()))
}

/// "3 × 10" when every set targets the same reps, otherwise "10 / 8 / 6 reps".
func repSummary(for item: RoutineItem) -> String {
    let reps = item.templateSets
        .sorted { $0.orderIndex < $1.orderIndex }
        .map(\.targetReps)

    guard !reps.isEmpty else { return "No sets" }

    if Set(reps).count == 1 {
        return "\(reps.count) × \(reps[0])"
    }
    return reps.map(String.init).joined(separator: " / ") + " reps"
}

let weekdayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

func todayWeekdayName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter.string(from: Date())
}

// MARK: - Routine Row

/// A routine list row showing muscle focus, superset indicator, schedule, and
/// when the routine was last performed. Tapping the row opens a preview; the
/// buttons handle edit and start. Long-press for the full action menu.
struct RoutineRowView: View {
    let routine: Routine
    /// Completed sessions, newest first — supplied by the parent so every row
    /// shares one query.
    let completedSessions: [WorkoutSession]
    /// Weekday names this routine is assigned to in the weekly plan.
    let scheduledDays: [String]
    let onPreview: () -> Void
    let onEdit: () -> Void
    let onStart: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    let onToggleDay: (String) -> Void

    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90

    private var isToday: Bool {
        scheduledDays.contains(todayWeekdayName())
    }

    private var muscleGroups: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for item in routine.items.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            if let exercise = item.exercise, !exercise.isDeleted {
                let group = exercise.muscleGroup
                if !seen.contains(group) {
                    seen.insert(group)
                    ordered.append(group)
                }
            }
        }
        return ordered
    }

    private var hasSuperset: Bool {
        routine.items.contains { $0.supersetID != nil }
    }

    private var lastPerformed: Date? {
        let routineID = routine.id
        return completedSessions.first { session in
            session.sets.contains { $0.routineItem?.routine?.id == routineID }
        }?.date
    }

    var body: some View {
        HStack {
            Button(action: onPreview) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(routine.name).font(.headline)

                        if isToday {
                            Text("TODAY")
                                .font(.caption2).bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.18))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                                .accessibilityLabel("Scheduled for today")
                        }

                        if hasSuperset {
                            Image(systemName: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.pink)
                                .accessibilityLabel("Contains superset")
                        }
                    }

                    HStack(spacing: 6) {
                        Text("\(routine.items.count) exercises")
                            .font(.caption).foregroundStyle(.secondary)

                        ForEach(muscleGroups.prefix(3), id: \.self) { group in
                            Text(group)
                                .font(.caption2).fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                        }
                        if muscleGroups.count > 3 {
                            Text("+\(muscleGroups.count - 3)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }

                    Text(detailLine)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onEdit) {
                Image(systemName: "pencil.circle")
                    .font(.title2).foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .accessibilityLabel("Edit \(routine.name)")

            Button("Start", action: onStart)
                .buttonStyle(.borderedProminent)
                .tint(.green)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Start Workout", systemImage: "play.fill", action: onStart)
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Duplicate", systemImage: "plus.square.on.square", action: onDuplicate)

            Menu("Assign to Day") {
                ForEach(weekdayNames, id: \.self) { day in
                    Button {
                        onToggleDay(day)
                    } label: {
                        if scheduledDays.contains(day) {
                            Label(day, systemImage: "checkmark")
                        } else {
                            Text(day)
                        }
                    }
                }
            }

            Divider()

            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    // "Last done 3 days ago · ~45 min · Mon/Thu"
    private var detailLine: String {
        var parts = [lastPerformedText]

        let minutes = estimatedMinutes(for: routine, restSeconds: defaultRestSeconds)
        if minutes > 0 {
            parts.append("~\(minutes) min")
        }

        if !scheduledDays.isEmpty {
            let ordered = weekdayNames.filter { scheduledDays.contains($0) }
            parts.append(ordered.map { String($0.prefix(3)) }.joined(separator: "/"))
        }

        return parts.joined(separator: " · ")
    }

    private var lastPerformedText: String {
        guard let date = lastPerformed else { return "Never performed" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Last done \(formatter.localizedString(for: date, relativeTo: Date()))"
    }
}

// MARK: - Routine Preview Sheet
/// Read-only look at what's inside a routine, with Start/Edit shortcuts.
struct RoutinePreviewSheet: View {
    let routine: Routine
    let onEdit: () -> Void
    let onStart: () -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultRestSeconds") private var defaultRestSeconds = 90

    private var sortedItems: [RoutineItem] {
        routine.items.sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        NavigationStack {
            List {
                if !routine.note.isEmpty {
                    Section("Note") {
                        Text(routine.note).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                Section {
                    LabeledContent("Estimated Duration") {
                        Text("~\(estimatedMinutes(for: routine, restSeconds: defaultRestSeconds)) min")
                    }
                    LabeledContent("Total Sets") {
                        Text("\(routine.items.reduce(0) { $0 + $1.templateSets.count })")
                    }
                }

                Section("Exercises") {
                    ForEach(sortedItems) { item in
                        HStack {
                            if item.supersetID != nil {
                                Capsule().fill(Color.pink).frame(width: 4).padding(.vertical, 2)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                if let exercise = item.exercise, !exercise.isDeleted {
                                    Text(exercise.name).font(.headline)
                                    HStack(spacing: 6) {
                                        Text(repSummary(for: item))
                                        Text("· \(exercise.muscleGroup)")
                                        if item.supersetID != nil {
                                            Text("· Superset").foregroundStyle(.pink).fontWeight(.bold)
                                        }
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                } else {
                                    Text("Deleted Exercise").font(.headline).foregroundStyle(.red)
                                    HStack(spacing: 6) {
                                        Text(repSummary(for: item))
                                        if item.supersetID != nil {
                                            Text("· Superset").foregroundStyle(.pink).fontWeight(.bold)
                                        }
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }

                                if let note = item.note, !note.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "wand.and.stars").font(.caption2)
                                        Text(note).font(.caption)
                                    }
                                    .foregroundStyle(.purple)
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        dismiss()
                        onStart()
                    } label: {
                        Label("Start Workout", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .listRowBackground(Color.green)
                    .foregroundStyle(.white)
                }
            }
            .navigationTitle(routine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        dismiss()
                        onEdit()
                    }
                }
            }
        }
    }
}
