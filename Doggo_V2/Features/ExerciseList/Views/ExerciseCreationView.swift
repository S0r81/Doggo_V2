//
//  ExerciseCreationView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ExerciseCreationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// When set, the form edits this exercise in place instead of creating one.
    var exerciseToEdit: Exercise? = nil

    @State private var name: String = ""
    @State private var selectedMuscle: String = "Chest"
    @State private var selectedType: String = "Strength"

    // Cardio tracking — a closed enum, never free text, so analytics and
    // CSV round-trips always understand the metric.
    @State private var selectedTracking: CardioTrackingType = .distance

    // Expanded list for better categorization (@State so an edited exercise's
    // group — e.g. AI-created "Other" — can be appended when it's not listed)
    @State private var muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body"]
    let types = ["Strength", "Cardio", "Olympic", "Accessory"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Details")) {
                    TextField("Exercise Name (e.g., Squat)", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    Picker("Muscle Group", selection: $selectedMuscle) {
                        ForEach(muscleGroups, id: \.self) { muscle in
                            Text(muscle).tag(muscle)
                        }
                    }
                    
                    Picker("Type", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    // Only shown for Cardio — pick how the session is measured
                    if selectedType == "Cardio" {
                        Picker("Tracking Metric", selection: $selectedTracking) {
                            ForEach(CardioTrackingType.allCases) { tracking in
                                Label(tracking.label, systemImage: tracking.icon)
                                    .tag(tracking)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section {
                    if selectedType == "Cardio" {
                        Text(selectedTracking == .timeOnly
                             ? "Tracking: Time only"
                             : "Tracking: \(selectedTracking.label) + Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(exerciseToEdit == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let exercise = exerciseToEdit {
                    name = exercise.name
                    selectedType = exercise.type
                    selectedTracking = exercise.cardioTracking
                    if !muscleGroups.contains(exercise.muscleGroup) {
                        muscleGroups.append(exercise.muscleGroup)
                    }
                    selectedMuscle = exercise.muscleGroup
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        HapticManager.shared.notification(type: .success)
                        saveExercise()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveExercise() {
        let trackingRaw = selectedType == "Cardio"
            ? selectedTracking.rawValue
            : CardioTrackingType.distance.rawValue

        if let exercise = exerciseToEdit {
            // Update in place — all logged history stays attached
            exercise.name = name
            exercise.type = selectedType
            exercise.muscleGroup = selectedMuscle
            exercise.cardioType = trackingRaw
            modelContext.saveLogging()
        } else {
            let newExercise = Exercise(
                name: name,
                type: selectedType,
                muscleGroup: selectedMuscle,
                cardioType: trackingRaw,
                isCustom: true // <--- EXPLICITLY set to TRUE
            )
            modelContext.insert(newExercise)
        }
        dismiss()
    }
}
