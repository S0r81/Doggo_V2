//
//  ExerciseListView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @Query(sort: \Exercise.name) var exercises: [Exercise]
    var currentSession: WorkoutSession
    var onAdd: (Exercise) -> Void
    
    // 1. Add State for the sheet
    @State private var showCreateSheet = false
    @State private var searchText = ""
    
    var groupedExercises: [String: [Exercise]] {
        let filtered = exercises.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return Dictionary(grouping: filtered, by: { $0.muscleGroup })
    }
    
    var muscleGroups: [String] { groupedExercises.keys.sorted() }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(muscleGroups, id: \.self) { group in
                    Section(header: Text(group)) {
                        ForEach(groupedExercises[group] ?? []) { exercise in
                            Button(action: {
                                onAdd(exercise)
                                dismiss()
                            }) {
                                HStack {
                                    Text(exercise.name).foregroundStyle(.primary)
                                    Spacer()
                                    Text(exercise.type)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(4)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Add Exercise")
            // 2. Update Toolbar to have Cancel AND Plus button
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // 3. Present the Creation Sheet
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    ExerciseCreationView()
                }
                .presentationDetents([.medium])
            }
        }
    }
}

