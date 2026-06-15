//
//  NutritionOnboardingView.swift
//  Doggo_V2
//
//  Phase 3: the paginated intake questionnaire. Gathers every input
//  MacroCalculator.prescribe needs, shows a live preview of the resulting
//  targets, then hands the computed values to the @ModelActor
//  NutritionRepository (value-in / id-out) to create the diet profile.
//

import SwiftUI
import SwiftData
import UIKit

struct NutritionOnboardingView: View {
    /// Called with the new profile's id once it is saved.
    var onComplete: (PersistentIdentifier) -> Void = { _ in }
    /// Hidden when shown as a tab root (nothing to cancel back to).
    var allowsCancel: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    // Inputs
    @State private var page = 0
    @State private var weightInput: Double = 0
    @State private var goalWeightInput: Double = 0
    @State private var sex: BiologicalSex = .male
    @State private var age = 30
    @State private var knowsBodyFat = false
    @State private var bodyFat: Double = 20
    @State private var activity: ActivityLevel = .moderate
    @State private var resistanceTraining = true
    @State private var protein: ProteinPreference = .high
    @State private var lossRate: Double = 0.006

    // Save state
    @State private var isSaving = false
    @State private var errorMessage: String?

    // Keyboard focus — the two decimal-pad fields (weight, goal) have no native
    // Return key, so we drive dismissal explicitly through this.
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case weight, goal }

    private let totalPages = 9
    private var accent: Color { Color.accent(for: userTheme) }

    // MARK: - Derived

    private var weightKg: Double {
        unitSystem == .imperial ? weightInput / UnitSystem.poundsPerKilogram : weightInput
    }

    private var goalWeightKg: Double {
        unitSystem == .imperial ? goalWeightInput / UnitSystem.poundsPerKilogram : goalWeightInput
    }

    /// Skipped body-fat falls back to a sex-based estimate.
    private var effectiveBodyFat: Double {
        if knowsBodyFat { return bodyFat }
        return sex == .male ? 18 : 28
    }

    private var input: DietInput {
        DietInput(
            weightKg: weightKg,
            bodyFatPercent: effectiveBodyFat,
            sex: sex,
            ageYears: age,
            weeklyLossRate: lossRate,
            protein: protein,
            resistanceTraining: resistanceTraining,
            activity: activity
        )
    }

    private var prescription: DietPrescription { MacroCalculator.prescribe(input) }

    private var canAdvance: Bool {
        switch page {
        case 0: return weightKg > 25 && weightKg < 350   // sane bounds
        case 7: return goalWeightKg > 25 && goalWeightKg < weightKg
        default: return true
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar

                TabView(selection: $page) {
                    weightPage.tag(0)
                    sexPage.tag(1)
                    agePage.tag(2)
                    bodyFatPage.tag(3)
                    activityPage.tag(4)
                    trainingPage.tag(5)
                    ratePage.tag(6)
                    goalPage.tag(7)
                    summaryPage.tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.snappy, value: page)

                navButtons
            }
            .background(Color.background(for: userTheme).ignoresSafeArea())
            .navigationTitle("Build Your Diet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if allowsCancel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                // Native "Done" above the decimal pad, which has no Return key.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { dismissKeyboard() }
                }
            }
            // Catches BOTH button-driven and swipe-driven page changes, so the
            // keypad never survives a page transition.
            .onChange(of: page) { _, _ in dismissKeyboard() }
            .onAppear {
                if weightInput == 0 { weightInput = unitSystem == .imperial ? 175 : 80 }
                if goalWeightInput == 0 { goalWeightInput = weightInput * 0.9 }
            }
            .alert("Couldn’t Save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    // MARK: - Chrome

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule().fill(accent)
                    .frame(width: geo.size.width * CGFloat(page + 1) / CGFloat(totalPages))
                    .animation(.snappy, value: page)
            }
        }
        .frame(height: 6)
        .padding(.horizontal)
        .padding(.top, Spacing.sm)
    }

    private var navButtons: some View {
        HStack(spacing: Spacing.md) {
            if page > 0 {
                Button {
                    dismissKeyboard()
                    withAnimation(.snappy) { page -= 1 }
                } label: {
                    Label("Back", systemImage: "chevron.left")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.bordered)
            }

            if page < totalPages - 1 {
                Button {
                    dismissKeyboard()
                    withAnimation(.snappy) { page += 1 }
                    HapticManager.shared.impact(style: .light)
                } label: {
                    Text("Next")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(!canAdvance)
            }
        }
        .padding()
    }

    private func pageScaffold<Content: View>(
        _ title: String,
        _ subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title).font(.title.bold())
                Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
            }
            content()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(Spacing.xl)
        // Tap anywhere off the fields to drop the keyboard. contentShape makes
        // the empty area hittable; controls still receive their own taps.
        .contentShape(Rectangle())
        .onTapGesture { dismissKeyboard() }
    }

    /// Force-dismiss the keyboard: clear focus and resign first responder as a
    /// belt-and-suspenders fallback for the decimal pad (which has no Done key).
    private func dismissKeyboard() {
        focusedField = nil
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil
        )
    }

    // MARK: - Pages

    private var weightPage: some View {
        pageScaffold("Your Weight", "We’ll anchor your targets to this.") {
            HStack(spacing: Spacing.sm) {
                TextField("0", value: $weightInput, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .weight)
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.trailing)
                Text(unitSystem.weightLabel)
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var sexPage: some View {
        pageScaffold("Biological Sex", "Used by the BMR equation, not a judgment.") {
            Picker("Sex", selection: $sex) {
                Text("Male").tag(BiologicalSex.male)
                Text("Female").tag(BiologicalSex.female)
            }
            .pickerStyle(.segmented)
        }
    }

    private var agePage: some View {
        pageScaffold("Your Age", "Metabolic rate declines slightly with age.") {
            VStack(spacing: Spacing.md) {
                Text("\(age)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                Stepper("Age", value: $age, in: 14...90)
                    .labelsHidden()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var bodyFatPage: some View {
        pageScaffold("Body Fat %", "Optional — toggle off and we’ll estimate.") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Toggle("I know my body fat %", isOn: $knowsBodyFat.animation(.snappy))
                if knowsBodyFat {
                    Text("\(Int(bodyFat))%")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                    Slider(value: $bodyFat, in: 5...50, step: 1).tint(accent)
                } else {
                    Label("We’ll assume ~\(Int(effectiveBodyFat))% for a \(sex == .male ? "male" : "female").",
                          systemImage: "wand.and.stars")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var activityPage: some View {
        pageScaffold("Activity Level", "Everyday movement outside workouts.") {
            VStack(spacing: Spacing.sm) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    selectableRow(
                        title: activityTitle(level),
                        detail: activityDetail(level),
                        isSelected: activity == level
                    ) { activity = level }
                }
            }
        }
    }

    private var trainingPage: some View {
        pageScaffold("Training & Protein", "Lifting + protein protect muscle in a deficit.") {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Toggle("I do resistance training", isOn: $resistanceTraining)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Protein Strategy").font(.headline)
                    Picker("Protein", selection: $protein) {
                        Text("Standard").tag(ProteinPreference.normal)
                        Text("High").tag(ProteinPreference.high)
                    }
                    .pickerStyle(.segmented)
                    Text(protein == .high
                         ? "High protein (~2.2 g/kg) — best muscle retention and satiety."
                         : "Standard protein (~1.2 g/kg).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var ratePage: some View {
        let weeklyKg = weightKg * lossRate
        let weeklyDisplay = unitSystem == .imperial ? weeklyKg * UnitSystem.poundsPerKilogram : weeklyKg
        return pageScaffold("How Fast?", "Slower is more sustainable and spares muscle.") {
            VStack(spacing: Spacing.md) {
                Text(String(format: "%.1f%% / week", lossRate * 100))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(accent)
                Text(String(format: "≈ %.2f %@ per week", weeklyDisplay, unitSystem.weightLabel))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Slider(value: $lossRate, in: 0.004...0.010, step: 0.001).tint(accent)
                HStack {
                    Text("0.4% (gentle)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("1.0% (aggressive)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var goalPage: some View {
        pageScaffold("Goal Weight", "Where are you headed? You can change it later.") {
            VStack(spacing: Spacing.md) {
                HStack(spacing: Spacing.sm) {
                    TextField("0", value: $goalWeightInput, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .goal)
                        .font(.system(size: 56, weight: .heavy, design: .rounded))
                        .multilineTextAlignment(.trailing)
                    Text(unitSystem.weightLabel)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                if goalWeightKg >= weightKg {
                    Label("Goal should be below your current weight.", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var summaryPage: some View {
        let rx = prescription
        return pageScaffold("Your Plan", "Here’s where you’ll start. You can adjust later.") {
            VStack(spacing: Spacing.md) {
                summaryTile("Daily Calories", "\(Int(rx.startingDailyKcal.rounded()))", "kcal")
                HStack(spacing: Spacing.md) {
                    macroTile("Protein", rx.proteinGrams, accent)
                    macroTile("Carbs", rx.carbGrams, .orange)
                    macroTile("Fat", rx.fatGrams, .yellow)
                }
                summaryTile("Daily Deficit", "\(rx.dailyDeficitKcalRounded)", "kcal below maintenance")

                Button(action: generate) {
                    HStack(spacing: Spacing.sm) {
                        if isSaving { ProgressView().tint(.white) }
                        Text(isSaving ? "Saving…" : "Generate My Diet")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.borderedProminent)
                .tint(accent)
                .disabled(isSaving)
                .padding(.top, Spacing.sm)
            }
        }
    }

    // MARK: - Small components

    private func selectableRow(title: String, detail: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? accent : Color.secondary.opacity(0.4))
            }
            .padding(Spacing.md)
            .background(Color.cardSurface(for: userTheme), in: RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func summaryTile(_ label: String, _ value: String, _ unit: String) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.title3.bold()).monospacedDigit()
            Text(unit).font(.caption).foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
        .background(Color.cardSurface(for: userTheme), in: RoundedRectangle(cornerRadius: 12))
    }

    private func macroTile(_ label: String, _ grams: Double, _ color: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            Text("\(Int(grams.rounded()))g").font(.headline).monospacedDigit().foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private func activityTitle(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Very Active"
        case .veryActive: return "Extremely Active"
        }
    }

    private func activityDetail(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Desk job, little walking"
        case .light: return "Light walking, 1–3 days/week"
        case .moderate: return "On your feet, 3–5 days/week"
        case .active: return "Physical job or 6–7 days/week"
        case .veryActive: return "Hard labor or twice-daily training"
        }
    }

    // MARK: - Save

    private func generate() {
        isSaving = true
        let rx = prescription
        let config = NutritionProfileConfig(
            startingWeightKg: weightKg,
            goalWeightKg: goalWeightKg,
            targetLossRate: rx.clampedWeeklyLossRate,
            bodyFatPercent: effectiveBodyFat,
            sex: sex,
            ageYears: age,
            activity: activity,
            proteinPref: protein,
            resistanceTraining: resistanceTraining,
            maintenanceCalories: rx.maintenanceKcal,
            dailyCalories: rx.startingDailyKcal,
            deficitKcal: rx.dailyDeficitKcal,
            proteinGrams: rx.proteinGrams,
            carbGrams: rx.carbGrams,
            fatGrams: rx.fatGrams,
            phase: .deficit
        )
        let repository = NutritionRepository(modelContainer: modelContext.container)

        Task {
            do {
                let id = try await repository.createProfile(config)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isSaving = false
                    onComplete(id)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
