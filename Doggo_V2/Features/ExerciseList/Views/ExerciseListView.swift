//
//  ExerciseListView.swift
//  Doggo_V2
//

import SwiftUI
import SwiftData

struct ExerciseListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    // MARK: - THE FIX
    // We removed the 'sort' parameter entirely to prevent the "NSObject" error.
    // The sorting is now handled safely by the ViewModel.
    @Query var exercises: [Exercise]

    var currentSession: WorkoutSession?
    var onAdd: (Exercise) -> Void

    // MARK: - State
    @State private var viewModel = ExerciseListViewModel()
    @State private var showCreateSheet = false
    @State private var searchText = ""
    @State private var selectedFilter: String?
    @State private var exerciseToDelete: Exercise?
    // Name snapshot for the alert text — reading it off the model after deletion
    // crashes with "backing data could no longer be found in the store".
    @State private var pendingDeleteName = ""

    // Delegate sorting & grouping to ViewModel
    var groupedExercises: [String: [Exercise]] {
        viewModel.groupExercises(exercises, searchText: searchText, filter: selectedFilter)
    }

    var muscleGroups: [String] { groupedExercises.keys.sorted() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                FilterChipRow(
                    selection: $selectedFilter,
                    muscleGroups: viewModel.muscleGroupOptions(from: exercises)
                )
                exerciseList
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Exercises")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showCreateSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New exercise")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NavigationStack {
                    ExerciseCreationView()
                }
                .presentationDetents([.medium])
            }
            // Deleting an exercise cascade-deletes its workout history — confirm first.
            .alert("Delete Exercise?", isPresented: Binding(
                get: { exerciseToDelete != nil },
                set: { if !$0 { exerciseToDelete = nil } }
            )) {
                Button("Cancel", role: .cancel) { exerciseToDelete = nil }
                Button("Delete", role: .destructive) {
                    // Clear state first so nothing re-renders against the deleted model
                    let target = exerciseToDelete
                    exerciseToDelete = nil
                    if let target {
                        withAnimation { viewModel.deleteExercise(target, context: modelContext) }
                    }
                }
            } message: {
                Text("\"\(pendingDeleteName)\" and all of its logged sets will be permanently deleted.")
            }
        }
    }

    private var exerciseList: some View {
        List {
            if muscleGroups.isEmpty {
                if selectedFilter == "Favorites" && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Favorites Yet",
                        systemImage: "star",
                        description: Text("Swipe right on any exercise to add it to your favorites.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search or filter.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            ForEach(muscleGroups, id: \.self) { group in
                Section(header: Text("\(group) · \(groupedExercises[group]?.count ?? 0)")) {
                    ForEach(groupedExercises[group] ?? []) { exercise in
                        Button(action: {
                            onAdd(exercise)
                            dismiss()
                        }) {
                            // THIS IS THE NEW UI COMPONENT
                            ExerciseRow(exercise: exercise)
                        }
                        // MARK: - SWIPE: FAVORITE (Left)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                withAnimation { viewModel.toggleFavorite(exercise) }
                            } label: {
                                Label("Favorite", systemImage: exercise.isFavorite ? "star.slash" : "star")
                            }
                            .tint(.yellow)
                        }
                        // MARK: - SWIPE: DELETE (Right)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if exercise.isCustom {
                                Button(role: .destructive) {
                                    pendingDeleteName = exercise.name
                                    exerciseToDelete = exercise
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            } else {
                                Button {
                                    // System Protected
                                } label: {
                                    Label("System", systemImage: "lock")
                                }
                                .tint(.gray)
                            }
                        }
                    }
                }
            }
        }
    }
}
