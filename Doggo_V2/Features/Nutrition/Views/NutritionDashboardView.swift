//
//  NutritionDashboardView.swift
//  Doggo_V2
//
//  The diet hub. Reads the active NutritionProfile live via the parent's
//  @Query, so when the @ModelActor repository mutates targets or appends a
//  daily macro log, this view recomputes and the rings re-animate on their own.
//

import SwiftUI
import SwiftData
import Charts

struct NutritionDashboardView: View {
    let profile: NutritionProfile

    @Environment(\.modelContext) private var modelContext
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    // Body weight is one shared store (BodyMeasurement) — the same data the
    // Progress tab logs and shows, so the two tabs always agree.
    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    @State private var showLogWeight = false
    @State private var showEdit = false
    @State private var showHistory = false
    @State private var quickLogMacro: MacroKind?
    @State private var isStartingReverse = false
    @State private var isLoggingCheckIn = false
    @State private var checkInResult: WeeklyCheckInResult?
    @State private var errorMessage: String?
    @State private var selectedDate: Date?   // chart scrub position (Date-typed)

    private var accent: Color { Color.accent(for: userTheme) }

    private var phaseColor: Color {
        switch profile.phase {
        case .deficit: return accent
        case .dietBreak: return .blue
        case .reverseDiet: return .green
        case .maintenance: return .gray
        }
    }

    private var today: DailyMacroLog? { profile.todaysLog() }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.xl) {
                    phaseHeader
                    if profile.hasReachedGoal && profile.phase == .deficit {
                        reverseDietPrompt
                    }
                    targetsCard
                    weightTrendCard
                    historyButton
                    logButton
                }
                .padding(Spacing.lg)
            }
            .background(Color.background(for: userTheme).ignoresSafeArea())
            .navigationTitle("Nutrition")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEdit = true } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Edit diet")
                }
            }
            // Single weight logger, shared with the Progress tab. On save it
            // runs the diet engine for this week.
            .sheet(isPresented: $showLogWeight) {
                BodyWeightLogSheet(onSaved: runCheckIn)
                    .presentationDetents([.medium])
            }
            .sheet(isPresented: $showEdit) {
                EditNutritionProfileView(profile: profile, container: modelContext.container)
            }
            .sheet(isPresented: $showHistory) {
                NutritionHistoryView(profile: profile, container: modelContext.container)
            }
            .sheet(item: $quickLogMacro) { macro in
                QuickLogMacroSheet(
                    macro: macro,
                    profileID: profile.persistentModelID,
                    container: modelContext.container
                )
            }
            .alert(checkInAlertTitle, isPresented: Binding(
                get: { checkInResult != nil },
                set: { if !$0 { checkInResult = nil } }
            )) {
                Button("Got it") { checkInResult = nil }
            } message: {
                Text(checkInAlertMessage)
            }
            .alert("Couldn’t Update Diet", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Phase header

    private var phaseHeader: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: profile.phase.icon)
                .font(.system(size: 40))
                .foregroundStyle(phaseColor)
            Text(profile.phase.label).font(.title2.bold())
            Text(phaseSubtitle)
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .background(phaseColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
    }

    private var phaseSubtitle: String {
        switch profile.phase {
        case .deficit: return "\(Int(profile.dailyDeficitKcal.rounded())) kcal/day below maintenance"
        case .dietBreak: return "Eating at maintenance to recover your metabolism"
        case .reverseDiet: return "Ramping calories up gradually to protect your results"
        case .maintenance: return "Holding steady at maintenance"
        }
    }

    // MARK: - Reverse-diet prompt

    private var reverseDietPrompt: some View {
        VStack(spacing: Spacing.sm) {
            Label("You’ve reached your goal weight!", systemImage: "flag.checkered").font(.headline)
            Text("Start a reverse diet to add calories back gradually and avoid rapid fat regain.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button(action: startReverseDiet) {
                HStack(spacing: Spacing.sm) {
                    if isStartingReverse { ProgressView().tint(.white) }
                    Text("Start Reverse Diet")
                }
                .font(.subheadline.bold()).frame(maxWidth: .infinity).padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.borderedProminent).tint(.green).disabled(isStartingReverse)
        }
        .padding(Spacing.lg).frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Targets + interactive rings

    private var targetsCard: some View {
        VStack(spacing: Spacing.lg) {
            VStack(spacing: Spacing.xs) {
                Text("\(Int(profile.currentDailyCalories.rounded()))")
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .foregroundStyle(phaseColor)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: profile.currentDailyCalories)
                Text("calorie target / day").font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: Spacing.lg) {
                MacroRing(kind: .protein,
                          consumed: today?.proteinConsumed ?? 0,
                          target: Int(profile.proteinTargetGrams.rounded())) { quickLogMacro = .protein }
                MacroRing(kind: .carbs,
                          consumed: today?.carbsConsumed ?? 0,
                          target: Int(profile.carbTargetGrams.rounded())) { quickLogMacro = .carbs }
                MacroRing(kind: .fats,
                          consumed: today?.fatsConsumed ?? 0,
                          target: Int(profile.fatTargetGrams.rounded())) { quickLogMacro = .fats }
            }

            Text("Tap a ring to log what you ate.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(Spacing.lg)
        .cardSurface(shadowed: true)
    }

    // MARK: - Weight trend chart (with scrubbing)

    private var weightTrendCard: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader("Weight Trend", icon: "chart.xyaxis.line")

            let series = measurements.sorted { $0.date < $1.date }
            if series.count < 2 {
                ContentUnavailableView(
                    "Not Enough Data Yet",
                    systemImage: "scalemass",
                    description: Text("Log your weight a couple of times to see your trend.")
                )
                .frame(height: 180)
            } else {
                Chart {
                    ForEach(series) { m in
                        LineMark(x: .value("Date", m.date),
                                 y: .value("Weight", displayWeight(m.weightKG)))
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(accent)
                        PointMark(x: .value("Date", m.date),
                                  y: .value("Weight", displayWeight(m.weightKG)))
                            .foregroundStyle(accent)
                    }

                    if profile.goalWeightKg > 0 {
                        RuleMark(y: .value("Goal", displayWeight(profile.goalWeightKg)))
                            .foregroundStyle(.green.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("Goal").font(.caption2).foregroundStyle(.green)
                            }
                    }

                    if let selectedDate, let sel = nearestMeasurement(to: selectedDate, in: series) {
                        RuleMark(x: .value("Selected", sel.date))
                            .foregroundStyle(.secondary.opacity(0.5))
                            .annotation(position: .top,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                VStack(spacing: 2) {
                                    Text(sel.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption2).foregroundStyle(.secondary)
                                    Text(String(format: "%.1f %@", displayWeight(sel.weightKG), unitSystem.weightLabel))
                                        .font(.caption.bold()).foregroundStyle(accent)
                                }
                                .padding(6)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                            }
                    }
                }
                .frame(height: 200)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXSelection(value: $selectedDate)
            }
        }
        .padding(Spacing.lg)
        .cardSurface()
    }

    private func nearestMeasurement(to date: Date, in series: [BodyMeasurement]) -> BodyMeasurement? {
        series.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }

    private func displayWeight(_ kg: Double) -> Double {
        unitSystem == .imperial ? kg * UnitSystem.poundsPerKilogram : kg
    }

    // MARK: - Buttons

    private var historyButton: some View {
        Button { showHistory = true } label: {
            Label("View History", systemImage: "list.bullet.clipboard")
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.bordered)
    }

    private var logButton: some View {
        Button { showLogWeight = true } label: {
            HStack(spacing: Spacing.sm) {
                if isLoggingCheckIn { ProgressView().tint(.white) }
                Label("Log Weekly Check-In", systemImage: "plus.circle.fill")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.borderedProminent).tint(accent)
        .disabled(isLoggingCheckIn)
    }

    // MARK: - Weekly check-in (driven by the shared weight log)

    /// Called by BodyWeightLogSheet after a weight is saved. Runs the diet
    /// engine for this week and surfaces the result.
    private func runCheckIn(kg: Double, date: Date) {
        isLoggingCheckIn = true
        let repository = NutritionRepository(modelContainer: modelContext.container)
        let id = profile.persistentModelID
        Task {
            do {
                let result = try await repository.logWeeklyCheckIn(profileID: id, averageWeight: kg, date: date)
                await MainActor.run {
                    HapticManager.shared.notification(type: result.macroAdjustmentApplied ? .warning : .success)
                    isLoggingCheckIn = false
                    checkInResult = result
                }
            } catch {
                await MainActor.run { isLoggingCheckIn = false }
            }
        }
    }

    private var checkInAlertTitle: String {
        guard let r = checkInResult else { return "" }
        if r.macroAdjustmentApplied { return "Metabolic Adaptation Detected" }
        if r.phaseChanged {
            switch r.phase {
            case .dietBreak: return "Time for a Diet Break"
            case .deficit: return "Back to Fat Loss"
            case .maintenance: return "Reverse Diet Complete"
            case .reverseDiet: return "Reverse Diet Started"
            }
        }
        if r.reachedGoal { return "You Hit Your Goal! 🎉" }
        return "Check-In Logged"
    }

    private var checkInAlertMessage: String {
        guard let r = checkInResult else { return "" }
        if r.macroAdjustmentApplied {
            return "Your loss stalled two weeks running, so we’ve trimmed your carbs and fat by 10% to break the plateau. Protein stays put.\n\nNew target: \(Int(r.newDailyCalories.rounded())) kcal · \(Int(r.newProteinGrams.rounded()))P / \(Int(r.newCarbGrams.rounded()))C / \(Int(r.newFatGrams.rounded()))F."
        }
        if r.phaseChanged {
            switch r.phase {
            case .dietBreak: return "You’ve dieted hard for 12 weeks. We’re moving you to maintenance for two weeks to recover your metabolism, then we’ll resume the cut."
            case .deficit: return "Diet break complete — back into a fresh deficit, recalculated for your new weight."
            case .maintenance: return "You’ve ramped all the way back to maintenance. Nicely done — your set point is protected."
            case .reverseDiet: return "We’ll add calories gradually each week to avoid rapid fat regain."
            }
        }
        if r.reachedGoal {
            return "You’ve reached your goal weight. Consider starting a reverse diet below to lock in your results."
        }
        let lostDisplay = unitSystem == .imperial ? r.actualWeightLost * UnitSystem.poundsPerKilogram : r.actualWeightLost
        return String(format: "Logged. You changed %.2f %@ since last week. Keep going.", lostDisplay, unitSystem.weightLabel)
    }

    // MARK: - Actions

    private func startReverseDiet() {
        isStartingReverse = true
        let repository = NutritionRepository(modelContainer: modelContext.container)
        let id = profile.persistentModelID
        Task {
            do {
                _ = try await repository.startReverseDiet(profileID: id)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isStartingReverse = false
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    errorMessage = error.localizedDescription
                    isStartingReverse = false
                }
            }
        }
    }
}

// MARK: - Interactive macro ring

/// Circular progress for one macro, tappable to quick-log. Fill is computed
/// math-safely (consumed / max(target, 1)) and animated with a satisfying
/// spring on appear and whenever consumption changes.
private struct MacroRing: View {
    let kind: MacroKind
    let consumed: Int
    let target: Int
    let action: () -> Void

    @State private var drawn: Double = 0

    private var fill: Double { Double(consumed) / max(Double(target), 1) }
    private var spring: Animation { .spring(response: 0.5, dampingFraction: 0.7, blendDuration: 0) }

    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                ZStack {
                    Circle().stroke(kind.color.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(drawn, 1))
                        .stroke(kind.color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(consumed)").font(.headline).monospacedDigit().foregroundStyle(kind.color)
                        Text("/ \(target)g").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 78, height: 78)
                Text(kind.label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .onAppear { withAnimation(spring) { drawn = fill } }
        .onChange(of: consumed) { _, _ in withAnimation(spring) { drawn = fill } }
        .onChange(of: target) { _, _ in withAnimation(spring) { drawn = fill } }
    }
}
