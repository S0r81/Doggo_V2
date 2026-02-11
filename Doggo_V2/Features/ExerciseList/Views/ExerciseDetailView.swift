//
//  ExerciseDetailView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI
import SwiftData
import Charts

struct ExerciseDetailView: View {
    // We use the setting here to decide what to CONVERT TO
    @AppStorage("unitSystem") private var preferredSystem: UnitSystem = .imperial
    
    let exercise: Exercise
    
    var history: [WorkoutSet] {
        return exercise.sets.sorted { ($0.workoutSession?.date ?? Date()) < ($1.workoutSession?.date ?? Date()) }
    }
    
    var isCardio: Bool {
        exercise.type == "Cardio"
    }
    
    // MARK: - Normalization Logic
    
    func normalizedWeight(_ set: WorkoutSet) -> Double {
        if preferredSystem == .imperial {
            // Want LBS. If set is KG, convert.
            return set.unit == "kg" ? set.weight * 2.20462 : set.weight
        } else {
            // Want KG. If set is LBS, convert.
            return set.unit == "lbs" ? set.weight * 0.453592 : set.weight
        }
    }
    
    func normalizedDistance(_ set: WorkoutSet) -> Double {
        let dist = set.distance ?? 0
        if preferredSystem == .imperial {
            // Want Miles. If set is KM, convert.
            return set.unit == "km" ? dist * 0.621371 : dist
        } else {
            // Want KM. If set is Miles, convert.
            return set.unit == "mi" ? dist * 1.60934 : dist
        }
    }
    
    // MARK: - Stats Calculations
    
    var personalRecordValue: String {
        if isCardio {
            let maxDist = history.map { normalizedDistance($0) }.max() ?? 0
            if maxDist < 0.1 {
                let maxTime = history.compactMap { $0.duration }.max() ?? 0
                return "\(maxTime.formatted()) min"
            }
            return "\(String(format: "%.2f", maxDist)) \(preferredSystem.distanceLabel)"
        } else {
            let maxWeight = history.map { normalizedWeight($0) }.max() ?? 0
            return "\(Int(maxWeight)) \(preferredSystem.weightLabel)"
        }
    }
    
    var personalRecordLabel: String {
        isCardio ? "Longest Run" : "Personal Record"
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // 1. Header Stats
                HStack(spacing: 20) {
                    // FIX: Renamed to DetailStatBox to avoid conflict
                    DetailStatBox(
                        title: personalRecordLabel,
                        value: personalRecordValue,
                        color: .green
                    )
                    
                    DetailStatBox(
                        title: "Total Sessions",
                        value: "\(history.count)",
                        color: .blue
                    )
                }
                .padding(.horizontal)
                
                // 2. The Chart
                if history.count > 1 {
                    VStack(alignment: .leading) {
                        Text(isCardio ? "Progress (Distance)" : "Progress (Max Weight)")
                            .font(.headline)
                        
                        Chart {
                            ForEach(history) { set in
                                if let date = set.workoutSession?.date {
                                    if isCardio {
                                        // Plot Normalized Distance
                                        LineMark(
                                            x: .value("Date", date),
                                            y: .value("Distance", normalizedDistance(set))
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color.accentColor)
                                    } else {
                                        // Plot Normalized Weight
                                        LineMark(
                                            x: .value("Date", date),
                                            y: .value("Weight", normalizedWeight(set))
                                        )
                                        .interpolationMethod(.catmullRom)
                                        .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                        .frame(height: 250)
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                } else {
                    ContentUnavailableView("Not enough data for chart", systemImage: "chart.xyaxis.line")
                        .frame(height: 200)
                }
                
                // 3. History List
                VStack(alignment: .leading) {
                    Text("History")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(history.reversed()) { set in
                        HStack {
                            // Date
                            Text(set.workoutSession?.date.formattedDate ?? "Unknown")
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            
                            Spacer()
                            
                            // THE ROW CONTENT
                            if isCardio {
                                VStack(alignment: .trailing) {
                                    // Show ORIGINAL stored unit
                                    Text("\(set.distance?.formatted() ?? "0") \(set.unit)")
                                        .bold()
                                    Text(formatDuration(minutes: set.duration ?? 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                HStack {
                                    // Show ORIGINAL stored unit
                                    Text("\(Int(set.weight)) \(set.unit)")
                                        .bold()
                                    Text("x")
                                    Text("\(set.reps)")
                                }
                            }
                        }
                        .padding()
                        .background(Color(uiColor: .secondarySystemBackground))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.top)
        }
        .navigationTitle(exercise.name)
    }
    
    func formatDuration(minutes: Double) -> String {
        let totalSeconds = Int(minutes * 60)
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        
        if h > 0 {
            return "\(h)h \(m)m"
        } else {
            return "\(m) min"
        }
    }
}

// FIX: Renamed struct to avoid conflict with the other StatBox
struct DetailStatBox: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .bold()
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

