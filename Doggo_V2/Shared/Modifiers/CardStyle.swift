//
//  CardStyle.swift
//  Doggo_V2
//

import SwiftUI

/// Themed card surface. Replaces hardcoded
/// `.background(Color(uiColor: .secondarySystemBackground)).cornerRadius(...)`
/// so cards follow the user's theme (Nordic gets #3B4252 instead of iOS grey).
struct CardSurfaceModifier: ViewModifier {
    @AppStorage("userTheme") private var userTheme: AppTheme = .light
    let cornerRadius: CGFloat
    let shadowed: Bool

    func body(content: Content) -> some View {
        content
            .background(Color.cardSurface(for: userTheme))
            .cornerRadius(cornerRadius)
            // Shadows are invisible on dark backgrounds; only draw them in light mode.
            .shadow(
                color: shadowed && userTheme == .light ? .black.opacity(0.05) : .clear,
                radius: 2, x: 0, y: 2
            )
    }
}

extension View {
    /// Applies the theme-aware card background with rounded corners.
    func cardSurface(cornerRadius: CGFloat = 16, shadowed: Bool = false) -> some View {
        modifier(CardSurfaceModifier(cornerRadius: cornerRadius, shadowed: shadowed))
    }
}
