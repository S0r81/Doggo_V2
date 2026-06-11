//
//  WorkoutFocusDetailView.swift
//  Doggo_V2
//

import SwiftUI

struct WorkoutFocusDetailView: View {
    let allSessions: [WorkoutSession]
    @Environment(\.dismiss) var dismiss
    
    // Interaction State
    @State private var selectedSegment: String? = nil
    
    // MATCHING COLORS (Must match WorkoutFocusCard)
    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo]
    
    // MARK: - Data Processing
    
    // 1. Chart Data (Grouped by Muscle)
    var muscleStats: [ExerciseStat] {
        var counts: [String: Int] = [:]
        for session in allSessions {
            for set in session.sets {
                // Assuming 'muscleGroup' is the property on your Exercise model
                if let muscle = set.exercise?.muscleGroup {
                    counts[muscle, default: 0] += 1
                }
            }
        }
        return counts.map { ExerciseStat(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
    
    // 2. Filtered History List
    var filteredHistory: [DailyWorkoutSummary] {
        guard let filter = selectedSegment else { return [] }
        
        var summaries: [DailyWorkoutSummary] = []
        
        for session in allSessions {
            // Find sets that match the selected muscle group
            let matchingSets = session.sets.filter { $0.exercise?.muscleGroup == filter }
            
            if !matchingSets.isEmpty {
                var exerciseCounts: [String: Int] = [:]
                for set in matchingSets {
                    if let name = set.exercise?.name {
                        exerciseCounts[name, default: 0] += 1
                    }
                }
                
                let details = exerciseCounts.map { "\($0.key): \($0.value) sets" }.sorted()
                
                summaries.append(DailyWorkoutSummary(
                    id: session.id,
                    date: session.date,
                    details: details
                ))
            }
        }
        return summaries.sorted { $0.date > $1.date }
    }
    
    struct DailyWorkoutSummary: Identifiable {
        let id: UUID
        let date: Date
        let details: [String]
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: - 1. All-Time Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("All-Time Focus")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if muscleStats.isEmpty {
                            ContentUnavailableView("No Data", systemImage: "chart.pie")
                                .padding(.top, 40)
                        } else {
                            // The Donut Chart
                            WorkoutFocusCard(data: muscleStats, selectedSegment: $selectedSegment)
                                .padding(.horizontal)
                        }
                    }
                    
                    // MARK: - 2. Content Area (Legend OR History)
                    VStack(alignment: .leading, spacing: 12) {
                        
                        if let selected = selectedSegment {
                            // STATE A: History List (When Selected)
                            HStack {
                                Text("\(selected) History")
                                    .font(.headline)
                                Spacer()
                                Button("Clear Selection") {
                                    withAnimation { selectedSegment = nil }
                                }
                                .font(.caption).foregroundStyle(Color.accentColor)
                            }
                            .padding(.horizontal)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            
                            if filteredHistory.isEmpty {
                                Text("No history found.")
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredHistory) { summary in
                                        historyRow(summary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            
                        } else {
                            // STATE B: Interactive Legend (When Nothing Selected)
                            if !muscleStats.isEmpty {
                                Text("Breakdown")
                                    .font(.headline)
                                    .padding(.horizontal)
                                    .transition(.move(edge: .leading).combined(with: .opacity))
                                
                                VStack(spacing: 0) {
                                    ForEach(Array(muscleStats.enumerated()), id: \.element.name) { index, stat in
                                        Button {
                                            withAnimation { selectedSegment = stat.name }
                                        } label: {
                                            HStack(spacing: 12) {
                                                // Color Dot
                                                Circle()
                                                    .fill(colors[index % colors.count])
                                                    .frame(width: 12, height: 12)
                                                
                                                Text(stat.name)
                                                    .font(.subheadline).bold()
                                                    .foregroundStyle(.primary)
                                                
                                                Spacer()
                                                
                                                Text("\(stat.count) sets")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.caption2)
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding()
                                            .cardSurface(cornerRadius: 0)
                                        }
                                        
                                        if index < muscleStats.count - 1 {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                }
                                .cornerRadius(16)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Workout Focus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
    
    // Helper View for History Rows
    private func historyRow(_ summary: DailyWorkoutSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(summary.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption).bold()
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            
            ForEach(summary.details, id: \.self) { detail in
                HStack {
                    Image(systemName: "dumbbell.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue.opacity(0.7))
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 12)
    }
}
