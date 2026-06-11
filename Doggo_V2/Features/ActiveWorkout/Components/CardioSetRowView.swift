//
//  CardioSetRowView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI

struct CardioSetRowView: View {
    @Bindable var set: WorkoutSet
    var index: Int
    // Keyboard focus owned by ActiveWorkoutView (shared "Done" toolbar).
    var focus: FocusState<WorkoutSetField?>.Binding

    // FIX: Explicitly define the body of the computed property
    private var cardioMode: String {
        return set.exercise?.cardioType ?? "Distance"
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 1. Interval Number
            Text("\(index)")
                .font(.caption)
                .bold()
                .foregroundStyle(.secondary)
                .frame(width: 20)
            
            // 2. Dynamic Input Fields
            Group {
                if cardioMode == "Distance" {
                    // FIELD A: Distance
                    VStack(spacing: 2) {
                        Text("Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        TextField("0", value: $set.distance, format: .number)
                            .focused(focus, equals: .distance(set.id))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.headline)
                            .padding(.vertical, 8)
                            .background(Color.accentColor.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                Menu {
                                    Button("mi") { set.unit = "mi" }
                                    Button("km") { set.unit = "km" }
                                } label: {
                                    Text(set.unit)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 4)
                                        .background(.thinMaterial)
                                        .cornerRadius(4)
                                }
                                .padding(.trailing, 8),
                                alignment: .trailing
                            )
                    }
                } else if cardioMode == "Steps" {
                    // FIELD A: Steps
                    VStack(spacing: 2) {
                        Text("Steps")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        TextField("0", value: $set.steps, format: .number)
                            .focused(focus, equals: .steps(set.id))
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.center)
                            .font(.headline)
                            .padding(.vertical, 8)
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "shoe.2.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.trailing, 8),
                                alignment: .trailing
                            )
                    }
                }
                
                // FIELD B: Time (Always shown for both modes, and for "Time" mode)
                VStack(spacing: 2) {
                    Text("Time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    TextField("0", value: $set.duration, format: .number)
                        .focused(focus, equals: .time(set.id))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.headline)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            Text("min")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 8),
                            alignment: .trailing
                        )
                }
            }
            .frame(maxWidth: .infinity)
            
            // 3. Completion Checkbox
            Button(action: {
                HapticManager.shared.impact(style: .medium)
                withAnimation(.snappy) {
                    set.isCompleted.toggle()
                }
            }) {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(set.isCompleted ? .green : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(set.isCompleted ? "Interval \(index) completed" : "Mark interval \(index) complete")
        }
        .padding(.vertical, 4)
    }
}
