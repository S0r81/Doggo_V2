//
//  FilterChipRow.swift
//  Doggo_V2
//

import SwiftUI

/// Horizontal row of one-tap filter chips: "All", "★ Favorites", then one per
/// muscle group. `selection` is nil for All, "Favorites", or a muscle group name.
struct FilterChipRow: View {
    @Binding var selection: String?
    let muscleGroups: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", icon: nil, value: nil)
                chip(label: "Favorites", icon: "star.fill", value: "Favorites")

                ForEach(muscleGroups, id: \.self) { group in
                    chip(label: group, icon: nil, value: group)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func chip(label: String, icon: String?, value: String?) -> some View {
        let isSelected = selection == value

        Button {
            withAnimation(.snappy) { selection = value }
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(isSelected ? .white : .yellow)
                }
                Text(label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Filter: \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    FilterChipRow(
        selection: .constant("Chest"),
        muscleGroups: ["Back", "Chest", "Legs", "Shoulders"]
    )
}
