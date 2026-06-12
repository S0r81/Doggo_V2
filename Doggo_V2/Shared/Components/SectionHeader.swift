//
//  SectionHeader.swift
//  Doggo_V2
//
//  One header pattern for every content section: headline title, optional
//  secondary-tinted icon, and either a standard "label ›" action or custom
//  trailing content (e.g. the chart pager). Replaces the four ad-hoc header
//  styles that used to coexist on the Dashboard.
//

import SwiftUI

struct SectionHeader<Trailing: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .foregroundStyle(.secondary)
            }
            Text(title)
                .font(.headline)
            Spacer()
            trailing
        }
        .padding(.horizontal)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String, icon: String? = nil) {
        self.init(title: title, icon: icon) { EmptyView() }
    }
}

extension SectionHeader where Trailing == SectionHeaderAction {
    /// Header with the standard "label ›" trailing action.
    init(_ title: String, icon: String? = nil, actionLabel: String, action: @escaping () -> Void) {
        self.init(title: title, icon: icon) {
            SectionHeaderAction(label: actionLabel, action: action)
        }
    }
}

/// The standard trailing affordance: accent-colored "label ›".
struct SectionHeaderAction: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Text(label)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
            }
            .font(.subheadline)
            .foregroundStyle(Color.accentColor)
        }
    }
}
