// FILE: Doggo_V2/Shared/Components/States/LoadingView.swift
//
// One loading vocabulary for every AI operation. Previously the planner,
// coach, and generator each had their own spinner layout.

import SwiftUI

struct LoadingView: View {
    let message: String

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text(message)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - AI Loading

struct AILoadingView: View {
    let title: String
    var subtitle: String? = nil
    /// AI calls can take 5–20s — always give the user a way out when the
    /// operation blocks the screen.
    var onCancel: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.4)

            VStack(spacing: Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }

            if let onCancel {
                Button("Cancel", role: .cancel, action: onCancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(Spacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? "")")
    }
}

/// Full-screen scrim variant for operations that block the whole view.
struct AILoadingOverlay: View {
    let title: String
    var subtitle: String? = nil
    var onCancel: (() -> Void)? = nil

    var body: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            AILoadingView(title: title, subtitle: subtitle, onCancel: onCancel)
                .cardSurface()
                .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
}

#Preview {
    LoadingView(message: "Generating workout...")
}
