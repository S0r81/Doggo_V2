//
//  ExerciseAnalyticsView.swift
//  Doggo
//
//  Created by Sorest on 1/16/26.
//

import SwiftUI
import Charts
import SwiftData

struct ExerciseAnalyticsView: View {
    let exercise: Exercise
    // Pass full history so we can calculate progression
    @Query(sort: \WorkoutSession.date, order: .forward) var allSessions: [WorkoutSession]
    
    // REMOVED: ViewModel dependency to fix the "missing member" error
    // We will calculate stats locally in this view.
    
    @State private var selectedDataPoint: AnalyticsDataPoint?
    @State private var rawSelectedDate: Date?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                
                // HEADER
                VStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.largeTitle).bold()
                        .multilineTextAlignment(.center)
                    
                    Text(exercise.muscleGroup.uppercased())
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 12)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.top)
                
                // 1RM CHART
                VStack(alignment: .leading) {
                    Text("Estimated 1 Rep Max")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    // FIXED: Call local function instead of viewModel
                    let data = get1RMProgression(for: exercise, sessions: allSessions)
                    
                    if data.count >= 2 {
                        Chart {
                            ForEach(data) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", point.value)
                                )
                                .interpolationMethod(.catmullRom) // Smooth curves
                                .symbol(Circle().strokeBorder(lineWidth: 2))
                                .foregroundStyle(Gradient(colors: [.blue, .purple]))
                                
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("1RM", point.value)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue.opacity(0.3), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                
                                if let selectedDate = rawSelectedDate {
                                    RuleMark(x: .value("Selected", selectedDate))
                                        .foregroundStyle(.gray.opacity(0.3))
                                }
                            }
                        }
                        .chartYScale(domain: .automatic(includesZero: false))
                        .frame(height: 250)
                        .padding()
                        // INTERACTION LOGIC
                        .chartOverlay { proxy in
                            GeometryReader { geometry in
                                Rectangle().fill(.clear).contentShape(Rectangle())
                                    .gesture(
                                        DragGesture()
                                            .onChanged { value in
                                                guard let plotFrame = proxy.plotFrame else { return }
                                                let x = value.location.x - geometry[plotFrame].origin.x
                                                if let date: Date = proxy.value(atX: x) {
                                                    rawSelectedDate = date
                                                    // Find closest point
                                                    selectedDataPoint = data.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
                                                }
                                            }
                                            .onEnded { _ in
                                                rawSelectedDate = nil
                                                selectedDataPoint = nil
                                            }
                                    )
                            }
                        }
                        // POPUP OVERLAY
                        .overlay(alignment: .top) {
                            if let point = selectedDataPoint {
                                VStack {
                                    Text("\(Int(point.value)) lbs")
                                        .font(.title2).bold()
                                    Text(point.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                .padding(8)
                                .background(.thinMaterial)
                                .cornerRadius(8)
                                .offset(y: -20)
                            }
                        }
                        
                    } else {
                        ContentUnavailableView("Not Enough Data", systemImage: "chart.line.uptrend.xyaxis", description: Text("Log at least 2 sessions to see your progress."))
                            .frame(height: 200)
                    }
                }
                .padding(.vertical)
                .cardSurface(cornerRadius: 16)
                .padding(.horizontal)
                
                // STATS GRID
                let data = get1RMProgression(for: exercise, sessions: allSessions)
                let best = data.map { $0.value }.max() ?? 0
                let start = data.first?.value ?? 0
                let improvement = best - start
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatBox(title: "Best 1RM", value: "\(Int(best))", unit: "lbs", color: .green)
                    StatBox(title: "Starting 1RM", value: "\(Int(start))", unit: "lbs", color: .gray)
                    StatBox(title: "Total Gain", value: "\(Int(improvement))", unit: "lbs", color: improvement >= 0 ? .blue : .red)
                    StatBox(title: "Sessions", value: "\(data.count)", unit: "total", color: .orange)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .navigationTitle("Analytics")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Local Math Logic (Moved from ViewModel)
    
    func calculateOneRepMax(weight: Double, reps: Int) -> Double {
        if reps == 1 { return weight }
        // Epley Formula: Weight * (1 + Reps/30)
        return weight * (1 + Double(reps) / 30.0)
    }
    
    func get1RMProgression(for exercise: Exercise, sessions: [WorkoutSession]) -> [AnalyticsDataPoint] {
        var history: [AnalyticsDataPoint] = []
        
        // Filter sessions that contain this exercise
        let relevantSessions = sessions.filter { session in
            session.sets.contains { $0.exercise?.id == exercise.id }
        }
        // Note: 'allSessions' is already sorted by Query, but good to be safe
        
        for session in relevantSessions {
            // Find the best set in this session
            let sets = session.sets.filter { $0.exercise?.id == exercise.id }
            var max1RM: Double = 0
            
            for set in sets {
                // Normalize weight to LBS for consistent charting
                var weight = set.weight
                if set.unit == "kg" { weight *= UnitSystem.poundsPerKilogram }
                
                let estimated1RM = calculateOneRepMax(weight: weight, reps: set.reps)
                if estimated1RM > max1RM {
                    max1RM = estimated1RM
                }
            }
            
            if max1RM > 0 {
                history.append(AnalyticsDataPoint(date: session.date, value: max1RM))
            }
        }
        
        return history
    }
}

// Reuse the StatBox from Dashboard
struct StatBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title)
                .bold()
                .foregroundStyle(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .cardSurface(cornerRadius: 12)
    }
}

