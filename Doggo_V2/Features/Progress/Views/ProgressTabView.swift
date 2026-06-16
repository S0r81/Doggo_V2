//
//  ProgressTabView.swift
//  Doggo_V2
//
//  The "am I getting stronger?" tab: personal records, training summary,
//  muscle balance, and body-weight tracking.
//

import SwiftUI
import SwiftData
import Charts

struct ProgressTabView: View {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    @Query(
        filter: #Predicate<WorkoutSession> { $0.isCompleted == true },
        sort: \WorkoutSession.date, order: .reverse
    ) private var sessions: [WorkoutSession]

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var showWeightLog = false
    @State private var showWeightHistory = false

    // Memoized aggregates. These scan the ENTIRE workout history, so computing
    // them in `body`/computed vars re-walked everything on every render. Now
    // they recompute only when `sessions` actually changes.
    @State private var records: [StrengthMath.PersonalRecord] = []
    @State private var muscleGroups: [(group: String, sets: Int)] = []
    @State private var thisMonthCount = 0
    @State private var streak = 0

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    trainingSummary
                    personalRecords
                    muscleBalance
                    bodyWeight
                }
                .padding(.vertical, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
            .background(Color.background(for: userTheme))
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: sessions, initial: true) { _, _ in recomputeStats() }
            .sheet(isPresented: $showWeightLog) {
                BodyWeightLogSheet()
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showWeightHistory) {
                BodyWeightHistorySheet()
            }
        }
    }

    // MARK: - Training Summary

    private var trainingSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("This Month")

            HStack(spacing: Spacing.lg) {
                summaryTile(value: "\(thisMonthCount)", label: "Workouts", icon: "dumbbell.fill")
                summaryTile(value: "\(streak)", label: "Day Streak", icon: "flame.fill")
                summaryTile(value: "\(records.count)", label: "Tracked PRs", icon: "trophy.fill")
            }
            .padding(.horizontal)
        }
    }

    /// Rebuilds the memoized aggregates from the current sessions. Called once
    /// on appear and again only when `sessions` changes.
    private func recomputeStats() {
        let calendar = Calendar.current
        records = StrengthMath.personalRecords(from: sessions)
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: Date()) ?? Date()
        muscleGroups = StrengthMath.setsPerMuscleGroup(from: sessions, since: twoWeeksAgo)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        thisMonthCount = sessions.filter { $0.date >= monthStart }.count
        streak = DashboardViewModel().getCurrentStreak(from: sessions)
    }

    private func summaryTile(value: String, label: String, icon: String) -> some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
        .cardSurface(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Personal Records

    @ViewBuilder
    private var personalRecords: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Personal Records", icon: "trophy")

            if records.isEmpty {
                ContentUnavailableView(
                    "No PRs Yet",
                    systemImage: "trophy",
                    description: Text("Complete a strength workout and your records appear here.")
                )
                .frame(height: 140)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(records.prefix(8).enumerated()), id: \.element.exerciseName) { index, record in
                        prRow(record)
                        if index < min(records.count, 8) - 1 {
                            Divider().padding(.leading, Spacing.lg)
                        }
                    }
                }
                .cardSurface()
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func prRow(_ record: StrengthMath.PersonalRecord) -> some View {
        let row = HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(record.exerciseName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: Spacing.xs) {
                Text("\(Int(record.weight)) \(record.unit) × \(record.reps)")
                    .font(.subheadline.bold())
                    .monospacedDigit()
                Text("est. 1RM \(Int(record.estimatedOneRepMax)) \(record.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(Spacing.lg)
        .contentShape(Rectangle())

        if let exercise = record.exercise, !exercise.isDeleted {
            NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                row
            }
            .buttonStyle(.plain)
        } else {
            row
        }
    }

    // MARK: - Muscle Balance

    @ViewBuilder
    private var muscleBalance: some View {
        let groups = muscleGroups
        let maxSets = groups.first?.sets ?? 1

        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.md) {
                SectionHeader("Muscle Balance", icon: "figure.strengthtraining.traditional")

                VStack(spacing: Spacing.md) {
                    ForEach(groups, id: \.group) { entry in
                        HStack(spacing: Spacing.md) {
                            Text(entry.group)
                                .font(.caption.weight(.medium))
                                .frame(width: 76, alignment: .leading)

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.secondary.opacity(0.12))
                                    Capsule()
                                        .fill(Color.accentColor.gradient)
                                        .frame(width: geo.size.width * CGFloat(entry.sets) / CGFloat(maxSets))
                                }
                            }
                            .frame(height: 10)

                            Text("\(entry.sets)")
                                .font(.caption.bold())
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(entry.group): \(entry.sets) sets in the last two weeks")
                    }
                }
                .padding(Spacing.lg)
                .cardSurface()
                .padding(.horizontal)

                Text("Completed sets per muscle group, last 14 days.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Body Weight

    private var bodyWeight: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Body Weight", icon: "scalemass") {
                HStack(spacing: Spacing.lg) {
                    if !measurements.isEmpty {
                        Button {
                            showWeightHistory = true
                        } label: {
                            HStack(spacing: 2) {
                                Text("Edit")
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.caption2.bold())
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.accentColor)
                        }
                        .accessibilityLabel("Edit weight history")
                    }

                    Button {
                        showWeightLog = true
                    } label: {
                        HStack(spacing: 2) {
                            Text("Log")
                            Image(systemName: "plus")
                                .font(.caption2.bold())
                        }
                        .font(.subheadline)
                        .foregroundStyle(Color.accentColor)
                    }
                }
            }

            if measurements.isEmpty {
                ContentUnavailableView(
                    "No Entries",
                    systemImage: "scalemass",
                    description: Text("Log your body weight to track it alongside your lifting.")
                )
                .frame(height: 120)
            } else {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    if let latest = measurements.first {
                        HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                            Text(displayWeight(latest.weightKG))
                                .font(.title.bold())
                                .monospacedDigit()
                            Text(unitSystem.weightLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if measurements.count > 1 {
                        Chart {
                            ForEach(measurements.reversed()) { entry in
                                LineMark(
                                    x: .value("Date", entry.date),
                                    y: .value("Weight", displayWeightValue(entry.weightKG))
                                )
                                .interpolationMethod(.catmullRom)
                                .symbol(Circle())
                                .foregroundStyle(Color.accentColor)
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 140)
                    }
                }
                .padding(Spacing.lg)
                .cardSurface()
                .padding(.horizontal)
            }
        }
    }

    private func displayWeight(_ kg: Double) -> String {
        String(format: "%.1f", displayWeightValue(kg))
    }

    /// Numeric weight in the display unit — used for chart plotting so we never
    /// round-trip through a locale-formatted string.
    private func displayWeightValue(_ kg: Double) -> Double {
        unitSystem == .imperial ? kg * UnitSystem.poundsPerKilogram : kg
    }
}

// MARK: - Body Weight Log Sheet
// Creates a new entry or edits an existing one (weight + date), with sanity
// validation so a typo like "1850" can't poison the trend chart.

struct BodyWeightLogSheet: View {
    var entryToEdit: BodyMeasurement? = nil
    /// Fired after a successful save with (weightKg, date). Lets the nutrition
    /// tab run its weekly diet check-in off the single, canonical weight log.
    var onSaved: (Double, Date) -> Void = { _, _ in }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial
    @Query private var profiles: [UserProfile]

    @State private var weight: Double?
    @State private var date = Date()
    @State private var validationMessage: String?
    @FocusState private var weightFocused: Bool

    /// Plausible human body-weight band, in the display unit.
    private var validRange: ClosedRange<Double> {
        unitSystem == .imperial ? 50...1000 : 22...450
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.xl) {
                HStack(spacing: Spacing.sm) {
                    TextField("0", value: $weight, format: .number)
                        .focused($weightFocused)
                        .keyboardType(.decimalPad)
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 160)

                    Text(unitSystem.weightLabel)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, Spacing.xl)

                // Backdating / correcting the entry date
                DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .padding(.horizontal, Spacing.xl)

                if let validationMessage {
                    Label(validationMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    save()
                } label: {
                    Label(entryToEdit == nil ? "Save Weight" : "Update Entry", systemImage: "checkmark")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .disabled((weight ?? 0) <= 0)
                .padding(.horizontal)

                Spacer()
            }
            .navigationTitle(entryToEdit == nil ? "Log Body Weight" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if let entry = entryToEdit {
                    let display = unitSystem == .imperial ? entry.weightKG * UnitSystem.poundsPerKilogram : entry.weightKG
                    weight = (display * 10).rounded() / 10
                    date = entry.date
                } else {
                    weightFocused = true
                }
            }
        }
    }

    private func save() {
        guard let weight, weight > 0 else { return }

        // Sanity check: catch fat-fingered entries before they hit the chart
        guard validRange.contains(weight) else {
            validationMessage = "That doesn't look like a body weight (\(PlateCalculator.format(weight)) \(unitSystem.weightLabel)). Expected \(Int(validRange.lowerBound))–\(Int(validRange.upperBound))."
            HapticManager.shared.notification(type: .error)
            return
        }

        let kg = unitSystem == .imperial ? weight * UnitSystem.kilogramsPerPound : weight

        if let entry = entryToEdit {
            entry.weightKG = kg
            entry.date = date
        } else {
            modelContext.insert(BodyMeasurement(date: date, weightKG: kg))
        }

        modelContext.saveLogging()
        BodyMeasurementSync.syncProfile(context: modelContext)
        HapticManager.shared.notification(type: .success)
        onSaved(kg, date)
        dismiss()
    }
}

// MARK: - Body Weight History
// The fix-a-typo surface: every entry listed, tap to edit, swipe to delete.

struct BodyWeightHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var entryToEdit: BodyMeasurement?

    var body: some View {
        NavigationStack {
            List {
                ForEach(measurements) { entry in
                    Button {
                        entryToEdit = entry
                    } label: {
                        HStack {
                            Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(displayWeight(entry.weightKG)) \(unitSystem.weightLabel)")
                                .bold()
                                .monospacedDigit()
                                .foregroundStyle(Color.accentColor)
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(measurements[index])
                    }
                    modelContext.saveLogging()
                    BodyMeasurementSync.syncProfile(context: modelContext)
                }
            }
            .overlay {
                if measurements.isEmpty {
                    ContentUnavailableView("No Entries", systemImage: "scalemass")
                }
            }
            .navigationTitle("Weight History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $entryToEdit) { entry in
                BodyWeightLogSheet(entryToEdit: entry)
                    .presentationDetents([.medium])
            }
        }
    }

    private func displayWeight(_ kg: Double) -> String {
        let value = unitSystem == .imperial ? kg * UnitSystem.poundsPerKilogram : kg
        return String(format: "%.1f", value)
    }
}

// MARK: - Profile Sync
// The AI coach reads UserProfile.weightKG — keep it pinned to the newest
// measurement no matter how entries are added, edited, or deleted.

enum BodyMeasurementSync {
    @MainActor
    static func syncProfile(context: ModelContext) {
        var descriptor = FetchDescriptor<BodyMeasurement>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let latest = try? context.fetch(descriptor).first else { return }

        if let profile = (try? context.fetch(FetchDescriptor<UserProfile>()))?.first {
            profile.weightKG = latest.weightKG
            context.saveLogging()
        }
    }
}
