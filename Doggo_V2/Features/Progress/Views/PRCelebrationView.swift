//
//  PRCelebrationView.swift
//  Doggo_V2
//
//  The full-screen moment when a set beats an all-time record.
//

import SwiftUI

struct PRMoment: Equatable {
    let exerciseName: String
    let weight: Double
    let unit: String
}

struct PRCelebrationView: View {
    let moment: PRMoment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .symbolEffect(.bounce, value: appeared)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.4)

            Text("NEW PR!")
                .font(.title.bold())
                .tracking(2)

            VStack(spacing: Spacing.xs) {
                Text(moment.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(Int(moment.weight)) \(moment.unit)")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(Spacing.xl * 1.5)
        .cardSurface()
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .padding(.horizontal, 40)
        .onAppear {
            withAnimation(.bouncy) { appeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("New personal record: \(moment.exerciseName), \(Int(moment.weight)) \(moment.unit)")
    }
}
