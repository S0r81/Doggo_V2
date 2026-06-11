//
//  ExerciseRow.swift
//  Doggo_V2
//
//  Created by Sorest on 2/13/26.
//


import SwiftUI
import SwiftData

struct ExerciseRow: View {
    @Environment(\.modelContext) private var modelContext
    let exercise: Exercise

    // Loaded once on appear (same one-shot pattern as the ghost values in
    // SetRowView) so the list doesn't hold a live query per row.
    @State private var lastUsedSummary: String?
    @State private var prSummary: String?

    var body: some View {
        // A deleted model's properties crash on access ("backing data could no
        // longer be found"); rows can still be asked to render mid-exit-animation.
        if exercise.isDeleted {
            EmptyView()
        } else {
            content
        }
    }

    private var content: some View {
        HStack {
            // 1. Icon (Dumbbell vs Runner)
            Image(systemName: exercise.type == "Cardio" ? "figure.run" : "dumbbell.fill")
                .foregroundStyle(exercise.type == "Cardio" ? .orange : Color.accentColor)
                .frame(width: 24)

            // 2. Name, Star & Last Used
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .foregroundStyle(.primary)
                        .fontWeight(exercise.isFavorite ? .semibold : .regular)

                    if exercise.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                            .accessibilityLabel("Favorite")
                    }
                }

                if lastUsedSummary != nil || prSummary != nil {
                    Text([lastUsedSummary, prSummary].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 3. Type Badge
            Text(exercise.type)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .cardSurface(cornerRadius: 4)
        }
        .onAppear { loadLastUsed() }
    }

    private func loadLastUsed() {
        guard lastUsedSummary == nil, !exercise.isDeleted else { return }

        let exerciseID = exercise.id
        var descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> {
                $0.exercise?.id == exerciseID && $0.isCompleted == true
            },
            sortBy: [SortDescriptor(\WorkoutSet.workoutSession?.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let last = try? modelContext.fetch(descriptor).first,
              let date = last.workoutSession?.date else { return }

        let dateText = date.formatted(date: .abbreviated, time: .omitted)

        if last.isStepsBased, let steps = last.steps, steps > 0 {
            lastUsedSummary = "Last: \(steps) steps · \(dateText)"
        } else if exercise.type == "Cardio" {
            let distance = last.distance ?? 0
            guard distance > 0 else { return }
            lastUsedSummary = "Last: \(distance.formatted()) \(last.unit) · \(dateText)"
        } else {
            guard last.weight > 0 else { return }
            lastUsedSummary = "Last: \(Int(last.weight)) \(last.unit) × \(last.reps)"
            loadPersonalRecord(exerciseID: exerciseID)
        }
    }

    /// Heaviest completed set ever (strength exercises only).
    private func loadPersonalRecord(exerciseID: UUID) {
        var descriptor = FetchDescriptor<WorkoutSet>(
            predicate: #Predicate<WorkoutSet> {
                $0.exercise?.id == exerciseID && $0.isCompleted == true && $0.weight > 0
            },
            sortBy: [SortDescriptor(\WorkoutSet.weight, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        guard let best = try? modelContext.fetch(descriptor).first else { return }
        prSummary = "PR \(Int(best.weight)) \(best.unit)"
    }
}
