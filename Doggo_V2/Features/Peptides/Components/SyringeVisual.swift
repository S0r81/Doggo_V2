//
//  SyringeVisual.swift
//  Doggo_V2
//
//  A U-100 insulin syringe drawn to scale, filled to the calculated pull and
//  marked at that tick — the peptide analogue of BarbellVisual. Purely
//  presentational.
//

import SwiftUI

struct SyringeVisual: View {
    /// Units to pull (0…100 typical).
    let units: Double
    var maxUnits: Double = 100
    var accent: Color = .accentColor

    private var fraction: Double {
        guard maxUnits > 0 else { return 0 }
        return max(0, min(units / maxUnits, 1))
    }

    var body: some View {
        GeometryReader { geo in
            let plungerWidth: CGFloat = 14
            let needleWidth: CGFloat = 26
            let barrelX = plungerWidth
            let barrelWidth = max(0, geo.size.width - plungerWidth - needleWidth)
            let midY = geo.size.height / 2
            let barrelHeight = geo.size.height * 0.5
            let barrelY = midY - barrelHeight / 2
            let fillWidth = barrelWidth * fraction

            ZStack(alignment: .topLeading) {
                // Plunger flange (left)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: plungerWidth, height: barrelHeight * 1.5)
                    .position(x: plungerWidth / 2, y: midY)

                // Barrel outline
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.secondary.opacity(0.45), lineWidth: 1.5)
                    .frame(width: barrelWidth, height: barrelHeight)
                    .position(x: barrelX + barrelWidth / 2, y: midY)

                // Fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(accent.opacity(0.85))
                    .frame(width: fillWidth, height: barrelHeight)
                    .position(x: barrelX + fillWidth / 2, y: midY)

                // Tick marks every 10 units
                ForEach(0...10, id: \.self) { tick in
                    let x = barrelX + barrelWidth * (CGFloat(tick) / 10)
                    let major = tick % 5 == 0
                    Rectangle()
                        .fill(Color.secondary.opacity(major ? 0.6 : 0.3))
                        .frame(width: 1, height: major ? barrelHeight * 0.7 : barrelHeight * 0.4)
                        .position(x: x, y: barrelY + barrelHeight / 2)
                }

                // Needle (right)
                Rectangle()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: needleWidth, height: 1.5)
                    .position(x: barrelX + barrelWidth + needleWidth / 2, y: midY)

                // Pull marker + label
                if units > 0 {
                    let markerX = barrelX + fillWidth
                    Rectangle()
                        .fill(accent)
                        .frame(width: 2, height: barrelHeight + 10)
                        .position(x: markerX, y: midY)

                    Text("\(Int(units.rounded())) u")
                        .font(.caption2.bold())
                        .foregroundStyle(accent)
                        .fixedSize()
                        .position(x: min(max(markerX, 14), geo.size.width - 14),
                                  y: barrelY - 2)
                }
            }
        }
        .frame(height: 56)
        .accessibilityElement()
        .accessibilityLabel("Syringe filled to \(Int(units.rounded())) of \(Int(maxUnits)) units")
    }
}
