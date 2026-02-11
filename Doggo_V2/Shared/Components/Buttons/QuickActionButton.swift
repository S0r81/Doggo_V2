import SwiftUI

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(title).fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .cornerRadius(20)
    }
}
