//
//  ExerciseListViewModel.swift
//  Doggo_V2
//

import Foundation
import SwiftData
import SwiftUI

@Observable
class ExerciseListViewModel {
    
    // MARK: - Actions
    
    func toggleFavorite(_ exercise: Exercise) {
        exercise.isFavorite.toggle()
    }
    
    func deleteExercise(_ exercise: Exercise, context: ModelContext) {
        // SAFETY CHECK: Only delete if it's custom
        if exercise.isCustom {
            context.delete(exercise)
        } else {
            // Optional: You could add logic here to just "Hide" it instead
            print("Cannot delete system exercise: \(exercise.name)")
        }
    }
    
    // MARK: - Helper: Grouping Logic
    /// `filter` is a muscle group name, the special value "Favorites", or nil for all.
    func groupExercises(_ exercises: [Exercise], searchText: String, filter: String? = nil) -> [String: [Exercise]] {
        // 1. Filter by search text
        var filtered = exercises.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }

        // 2. Filter by chip selection
        if let filter {
            if filter == "Favorites" {
                filtered = filtered.filter { $0.isFavorite }
            } else {
                filtered = filtered.filter { $0.muscleGroup == filter }
            }
        }

        // 3. Sort (Favorites first, then Alphabetical)
        let sorted = filtered.sorted {
            if $0.isFavorite != $1.isFavorite {
                return $0.isFavorite // True comes before False
            }
            return $0.name < $1.name
        }

        // 4. Group
        return Dictionary(grouping: sorted, by: { $0.muscleGroup })
    }

    /// Distinct muscle groups present in the library, for building filter chips.
    func muscleGroupOptions(from exercises: [Exercise]) -> [String] {
        Array(Set(exercises.map { $0.muscleGroup })).sorted()
    }
}
