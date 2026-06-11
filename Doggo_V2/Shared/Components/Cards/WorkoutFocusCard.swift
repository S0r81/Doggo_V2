//
//  WorkoutFocusCard.swift
//  Doggo_V2
//

import SwiftUI
import Charts

struct WorkoutFocusCard: View {
    let data: [ExerciseStat]
    @Binding var selectedSegment: String? // Changed to Binding
    
    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo]
    
    private var totalSets: Int {
        data.reduce(0) { $0 + $1.count }
    }
    
    private func color(for exerciseName: String) -> Color {
        if let index = data.firstIndex(where: { $0.name == exerciseName }) {
            return colors[index % colors.count]
        }
        return .gray
    }
    
    private var selectedStat: ExerciseStat? {
        guard let name = selectedSegment else { return nil }
        return data.first { $0.name == name }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // CENTER INFO
            if let stat = selectedStat {
                VStack(spacing: 2) {
                    Text("\(stat.count)")
                        .font(.title).bold()
                        .foregroundStyle(color(for: stat.name))
                    Text(stat.name) // Show Name
                        .font(.caption).bold()
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                VStack(spacing: 2) {
                    Text("\(totalSets)")
                        .font(.title).bold()
                        .foregroundStyle(.primary)
                    Text("Total Sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            }
            
            // THE CHART
            Chart(data) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.65),
                    angularInset: 2
                )
                .cornerRadius(5)
                .foregroundStyle(color(for: item.name)) // Use consistent colors
                .opacity(selectedSegment == nil || selectedSegment == item.name ? 1.0 : 0.3)
            }
            .chartLegend(.hidden)
            .frame(height: 180) // Fixed height for consistency
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture { location in
                            handleTap(at: location, in: geometry.size)
                        }
                }
            }
        }
        .padding()
        .cardSurface()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let breakdown = data.prefix(4)
            .map { "\($0.name) \($0.count) sets" }
            .joined(separator: ", ")
        return "Workout focus chart. \(totalSets) total sets. \(breakdown)"
    }
    
    // MARK: - Tap Logic (Kept exactly as you had it)
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.65
        
        guard distance >= innerRadius && distance <= outerRadius else {
            withAnimation { selectedSegment = nil }
            return
        }
        
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let tapPercentage = angle / (2 * .pi)
        
        var cumulativePercentage: Double = 0
        let total = Double(totalSets)
        
        for item in data {
            let segmentPercentage = Double(item.count) / total
            if tapPercentage >= cumulativePercentage && tapPercentage < cumulativePercentage + segmentPercentage {
                withAnimation {
                    if selectedSegment == item.name {
                        selectedSegment = nil
                    } else {
                        selectedSegment = item.name
                    }
                }
                return
            }
            cumulativePercentage += segmentPercentage
        }
    }
}
