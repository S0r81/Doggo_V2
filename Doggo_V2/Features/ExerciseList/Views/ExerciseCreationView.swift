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

    // NEW: Cardio Tracking Preference
    @State private var selectedCardioType: String = "Distance"

    // Expanded list for better categorization (@State so an edited exercise's
    // group — e.g. AI-created "Other" — can be appended when it's not listed)
    @State private var muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body"]
    let types = ["Strength", "Cardio", "Olympic", "Accessory"]
    let cardioTypes = ["Distance", "Steps", "Time"] // Maps to the logic we built
    
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
                    
                    // NEW: Only show if "Cardio" is selected
                    if selectedType == "Cardio" {
                        Picker("Tracking Metric", selection: $selectedCardioType) {
                            ForEach(cardioTypes, id: \.self) { cType in
                                Text(cType).tag(cType)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Section {
                    if selectedType == "Cardio" {
                        Text("Tracking: \(selectedCardioType) + Time")
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
                    selectedCardioType = exercise.cardioType
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
        if let exercise = exerciseToEdit {
            // Update in place — all logged history stays attached
            exercise.name = name
            exercise.type = selectedType
            exercise.muscleGroup = selectedMuscle
            exercise.cardioType = selectedType == "Cardio" ? selectedCardioType : "Distance"
            try? modelContext.save()
        } else {
            let newExercise = Exercise(
                name: name,
                type: selectedType,
                muscleGroup: selectedMuscle,
                cardioType: selectedType == "Cardio" ? selectedCardioType : "Distance",
                isCustom: true // <--- EXPLICITLY set to TRUE
            )
            modelContext.insert(newExercise)
        }
        dismiss()
    }
}
