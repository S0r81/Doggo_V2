//
//  View+Theme.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//

import SwiftUI

struct ThemedBackground: ViewModifier {
    let theme: AppTheme
    
    func body(content: Content) -> some View {
        ZStack {
            // 1. The Wallpaper Layer
            Color.background(for: theme)
                .ignoresSafeArea()
            
            // 2. The Content Layer
            content
                // If Nordic, make lists transparent so wallpaper shows
                .scrollContentBackground(theme == .nordic ? .hidden : .automatic)
                // If Nordic, generic backgrounds (like TextFields) need to be clear too
                .background(theme == .nordic ? Color.clear : Color(uiColor: .systemBackground))
        }
    }
}

extension View {
    func applyTheme(_ theme: AppTheme) -> some View {
        modifier(ThemedBackground(theme: theme))
    }
}

