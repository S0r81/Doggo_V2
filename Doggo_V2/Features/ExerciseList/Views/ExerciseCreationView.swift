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
    
    @State private var name: String = ""
    @State private var selectedMuscle: String = "Chest"
    @State private var selectedType: String = "Strength"
    
    // NEW: Cardio Tracking Preference
    @State private var selectedCardioType: String = "Distance"
    
    // Expanded list for better categorization
    let muscleGroups = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core", "Cardio", "Full Body"]
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
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
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
        // Updated to include cardioType
        let newExercise = Exercise(
            name: name,
            type: selectedType,
            muscleGroup: selectedMuscle,
            cardioType: selectedType == "Cardio" ? selectedCardioType : "Distance"
        )
        modelContext.insert(newExercise)
        dismiss()
    }
}
