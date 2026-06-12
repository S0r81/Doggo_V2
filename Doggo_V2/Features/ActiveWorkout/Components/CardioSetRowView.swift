//
//  CardioSetRowView.swift
//  Doggo
//
//  The cardio "Session Block": one continuous session per exercise — Time +
//  Distance (or Steps) inputs and a single Complete Session button. No sets,
//  no set numbers, no Add Set. The single backing WorkoutSet is enforced in
//  ActiveWorkoutViewModel.
//

import SwiftUI

struct CardioSetRowView: View {
    @Bindable var set: WorkoutSet
    // Keyboard focus owned by ActiveWorkoutView (shared "Done" toolbar).
    var focus: FocusState<WorkoutSetField?>.Binding

    private var tracking: CardioTrackingType {
        self.set.exercise?.cardioTracking ?? .distance
    }

    /// Completed sessions visually recede; the button stays full strength.
    private var completedDim: Double {
        self.set.isCompleted ? 0.55 : 1.0
    }

    var body: some View {
        VStack(spacing: Spacing.md) {
            // MARK: - Session Inputs (driven by the exercise's tracking type)
            HStack(spacing: Spacing.md) {
                switch tracking {
                case .distance:
                    distanceField
                case .steps, .floors, .laps:
                    countField
                case .timeOnly:
                    EmptyView() // time is the only metric — give it the full width
                }
                timeField
            }
            .opacity(completedDim)

            // MARK: - Complete Session
            completeButton
        }
        .padding(.vertical, Spacing.xs)
    }

    // MARK: - Fields

    private var distanceField: some View {
        VStack(spacing: Spacing.xs) {
            Text("Distance")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField("0", value: $set.distance, format: .number)
                .focused(focus, equals: .distance(set.id))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.bold))
                .padding(.vertical, 10)
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
                    .padding(.trailing, Spacing.sm),
                    alignment: .trailing
                )
        }
        .frame(maxWidth: .infinity)
    }

    /// Shared input for all count-based tracking (steps / floors / laps) —
    /// the count lives in `set.steps`, the label and icon follow the type.
    private var countField: some View {
        VStack(spacing: Spacing.xs) {
            Text(tracking.metricLabel ?? "Count")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField("0", value: $set.steps, format: .number)
                .focused(focus, equals: .steps(set.id))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.bold))
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    Image(systemName: tracking.icon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Spacing.sm),
                    alignment: .trailing
                )
                .accessibilityLabel(tracking.metricLabel ?? "Count")
        }
        .frame(maxWidth: .infinity)
    }

    private var timeField: some View {
        VStack(spacing: Spacing.xs) {
            Text("Time")
                .font(.caption2)
                .foregroundStyle(.secondary)

            TextField("0", value: $set.duration, format: .number)
                .focused(focus, equals: .time(set.id))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.title3.weight(.bold))
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    Text("min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, Spacing.sm),
                    alignment: .trailing
                )
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Complete Button

    @ViewBuilder
    private var completeButton: some View {
        let label = Label(
            set.isCompleted ? "Session Complete" : "Complete Session",
            systemImage: set.isCompleted ? "checkmark.circle.fill" : "circle"
        )
        .font(.subheadline.weight(.semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xs)

        if set.isCompleted {
            Button(action: toggleComplete) { label }
                .buttonStyle(.borderedProminent)
                .tint(.green)
        } else {
            Button(action: toggleComplete) { label }
                .buttonStyle(.bordered)
                .tint(.green)
        }
    }

    private func toggleComplete() {
        HapticManager.shared.impact(style: .medium)
        withAnimation(.snappy) {
            set.isCompleted.toggle()
        }
    }
}
