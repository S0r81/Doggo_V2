import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.title3)
                Spacer()
                Text(value)
                    .font(.title)
                    .bold()
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
}
