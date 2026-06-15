//
//  EditNutritionProfileView.swift
//  Doggo_V2
//
//  Edit the diet inputs and either recalculate macros from the engine or set
//  them by hand. Routes through NutritionRepository.updateProfile.
//

import SwiftUI
import SwiftData
import UIKit

struct EditNutritionProfileView: View {
    let profile: NutritionProfile
    let container: ModelContainer

    @Environment(\.dismiss) private var dismiss
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    @AppStorage("unitSystem") private var unitSystem: UnitSystem = .imperial

    // Inputs (seeded from the profile snapshot in init)
    @State private var weightInput: Double
    @State private var goalInput: Double
    @State private var sex: BiologicalSex
    @State private var age: Int
    @State private var bodyFat: Double
    @State private var activity: ActivityLevel
    @State private var protein: ProteinPreference
    @State private var resistanceTraining: Bool
    @State private var lossRate: Double

    // Manual override
    @State private var manualOverride: Bool
    @State private var manualProtein: Int
    @State private var manualCarbs: Int
    @State private var manualFats: Int

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var accent: Color { Color.accent(for: userTheme) }

    init(profile: NutritionProfile, container: ModelContainer) {
        self.profile = profile
        self.container = container
        let metric = (UserDefaults.standard.string(forKey: "unitSystem") == "metric")
        let factor = metric ? 1.0 : UnitSystem.poundsPerKilogram
        _weightInput = State(initialValue: profile.startingWeightKg * factor)
        _goalInput = State(initialValue: profile.goalWeightKg * factor)
        _sex = State(initialValue: profile.sex)
        _age = State(initialValue: profile.ageYears)
        _bodyFat = State(initialValue: profile.bodyFatPercent)
        _activity = State(initialValue: profile.activity)
        _protein = State(initialValue: profile.proteinPreference)
        _resistanceTraining = State(initialValue: profile.resistanceTraining)
        _lossRate = State(initialValue: profile.targetLossRate)
        _manualOverride = State(initialValue: false)
        _manualProtein = State(initialValue: Int(profile.proteinTargetGrams.rounded()))
        _manualCarbs = State(initialValue: Int(profile.carbTargetGrams.rounded()))
        _manualFats = State(initialValue: Int(profile.fatTargetGrams.rounded()))
    }

    private var weightKg: Double { unitSystem == .imperial ? weightInput / UnitSystem.poundsPerKilogram : weightInput }
    private var goalKg: Double { unitSystem == .imperial ? goalInput / UnitSystem.poundsPerKilogram : goalInput }

    var body: some View {
        NavigationStack {
            Form {
                statsSection
                strategySection
                overrideSection
            }
            .navigationTitle("Edit Diet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .alert("Couldn’t Save", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
            .safeAreaInset(edge: .bottom) { saveBar }
        }
    }

    // MARK: - Sections

    private var statsSection: some View {
        Section("Stats") {
            numberRow("Current Weight", value: $weightInput, unit: unitSystem.weightLabel)
            numberRow("Goal Weight", value: $goalInput, unit: unitSystem.weightLabel)
            Picker("Biological Sex", selection: $sex) {
                Text("Male").tag(BiologicalSex.male)
                Text("Female").tag(BiologicalSex.female)
            }
            Stepper("Age: \(age)", value: $age, in: 14...90)
            VStack(alignment: .leading) {
                Text("Body Fat: \(Int(bodyFat))%")
                Slider(value: $bodyFat, in: 5...50, step: 1).tint(accent)
            }
        }
    }

    private var strategySection: some View {
        Section("Strategy") {
            Picker("Activity", selection: $activity) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(activityLabel(level)).tag(level)
                }
            }
            Picker("Protein", selection: $protein) {
                Text("Standard").tag(ProteinPreference.normal)
                Text("High").tag(ProteinPreference.high)
            }
            Toggle("Resistance Training", isOn: $resistanceTraining)
            VStack(alignment: .leading) {
                Text(String(format: "Target Loss: %.1f%% / week", lossRate * 100))
                Slider(value: $lossRate, in: 0.004...0.010, step: 0.001).tint(accent)
            }
        }
    }

    private var overrideSection: some View {
        Section {
            Toggle("Manual Macro Override", isOn: $manualOverride.animation(.snappy))
            if manualOverride {
                macroRow("Protein", value: $manualProtein, color: .blue)
                macroRow("Carbs", value: $manualCarbs, color: .orange)
                macroRow("Fat", value: $manualFats, color: .yellow)
                LabeledContent("Total") {
                    Text("\(manualProtein * 4 + manualCarbs * 4 + manualFats * 9) kcal")
                        .monospacedDigit()
                }
            }
        } footer: {
            Text(manualOverride
                 ? "Your numbers are saved exactly as entered."
                 : "Off: macros are recalculated from your stats above.")
        }
    }

    private var saveBar: some View {
        Button(action: save) {
            HStack(spacing: Spacing.sm) {
                if isSaving { ProgressView().tint(.white) }
                Text(manualOverride ? "Save Macros" : "Recalculate & Save")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .disabled(isSaving || weightKg < 25 || goalKg < 25)
        .padding()
        .background(.bar)
    }

    // MARK: - Rows

    private func numberRow(_ title: String, value: Binding<Double>, unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 80)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func macroRow(_ title: String, value: Binding<Int>, color: Color) -> some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 70)
            Text("g").foregroundStyle(.secondary)
        }
    }

    private func activityLabel(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "Sedentary"
        case .light: return "Lightly Active"
        case .moderate: return "Moderately Active"
        case .active: return "Very Active"
        case .veryActive: return "Extremely Active"
        }
    }

    // MARK: - Save

    private func save() {
        isSaving = true
        let newConfig = NutritionProfileConfig(
            startingWeightKg: weightKg,
            goalWeightKg: goalKg,
            targetLossRate: lossRate,
            bodyFatPercent: bodyFat,
            sex: sex,
            ageYears: age,
            activity: activity,
            proteinPref: protein,
            resistanceTraining: resistanceTraining,
            maintenanceCalories: profile.maintenanceCalories,
            dailyCalories: profile.currentDailyCalories,
            deficitKcal: profile.dailyDeficitKcal,
            proteinGrams: profile.proteinTargetGrams,
            carbGrams: profile.carbTargetGrams,
            fatGrams: profile.fatTargetGrams,
            phase: profile.phase
        )
        let manual: (protein: Int, carbs: Int, fats: Int)? =
            manualOverride ? (manualProtein, manualCarbs, manualFats) : nil
        let repository = NutritionRepository(modelContainer: container)
        let id = profile.persistentModelID

        Task {
            do {
                try await repository.updateProfile(profileID: id, newConfig: newConfig, manualMacros: manual)
                await MainActor.run {
                    HapticManager.shared.notification(type: .success)
                    isSaving = false
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
