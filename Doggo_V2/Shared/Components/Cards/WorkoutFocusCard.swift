import SwiftUI
import Charts

struct WorkoutFocusCard: View {
    let data: [ExerciseStat]
    @State private var selectedSegment: String? = nil
    private let colors: [Color] = [.blue, .green, .orange, .purple, .pink]
    
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Workout Focus").font(.headline).padding(.horizontal)
            
            VStack(spacing: 8) {
                if let stat = selectedStat {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(color(for: stat.name))
                            .frame(width: 10, height: 10)
                        Text(stat.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Text("Tap a segment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Count", item.count),
                        innerRadius: .ratio(0.65),
                        angularInset: 2
                    )
                    .cornerRadius(5)
                    .foregroundStyle(by: .value("Name", item.name))
                    .opacity(selectedSegment == nil || selectedSegment == item.name ? 1.0 : 0.4)
                }
                .chartLegend(.hidden)
                .chartBackground { proxy in
                    VStack(spacing: 2) {
                        if let stat = selectedStat {
                            Text("\(stat.count)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(color(for: stat.name))
                            Text("sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(totalSets)")
                                .font(.title)
                                .bold()
                                .foregroundStyle(.primary)
                            Text("Total Sets")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(width: 180, height: 180)
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
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
            .cornerRadius(16)
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
        }
    }
    
    private func handleTap(at location: CGPoint, in size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let outerRadius = min(size.width, size.height) / 2
        let innerRadius = outerRadius * 0.65
        
        guard distance >= innerRadius && distance <= outerRadius else {
            withAnimation {
                selectedSegment = nil
            }
            return
        }
        
        var angle = atan2(dx, -dy)
        if angle < 0 {
            angle += 2 * .pi
        }
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
