//
//  Color+Theme.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//
import SwiftUI

// 1. The definitions of your themes
enum AppTheme: String, CaseIterable, Identifiable {
    case light
    case dark
    case nordic
    case gruvbox

    var id: String { self.rawValue }

    // Friendly name for the UI (short — four themes share a segmented control)
    var label: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .nordic: return "Nordic"
        case .gruvbox: return "Gruvbox"
        }
    }
}

// 2. The Color Palette
extension Color {
    // 1. The Accent (Buttons, Toggles)
    static func accent(for theme: AppTheme) -> Color {
        switch theme {
        case .light:
            return .blue
        case .dark:
            return .blue
        case .nordic:
            return Color(red: 136/255, green: 192/255, blue: 208/255) // #88C0D0 (Frosty Cyan)
        case .gruvbox:
            return Color(red: 254/255, green: 128/255, blue: 25/255) // #FE8019 (Bright Orange)
        }
    }

    // 2. The Background (The Wallpaper)
    static func background(for theme: AppTheme) -> Color {
        switch theme {
        case .nordic:
            return Color(red: 46/255, green: 52/255, blue: 64/255) // #2E3440 (Polar Night)
        case .gruvbox:
            return Color(red: 40/255, green: 40/255, blue: 40/255) // #282828 (Gruvbox bg0)
        case .dark:
            return .black
        case .light:
            return Color(uiColor: .systemGroupedBackground) // Standard iOS Grey
        }
    }

    // 3. The Card Surface (Cards, Chart containers, Badges)
    static func cardSurface(for theme: AppTheme) -> Color {
        switch theme {
        case .nordic:
            return Color(red: 59/255, green: 66/255, blue: 82/255) // #3B4252 (Polar Night, lighter)
        case .gruvbox:
            return Color(red: 60/255, green: 56/255, blue: 54/255) // #3C3836 (Gruvbox bg1)
        case .dark, .light:
            return Color(uiColor: .secondarySystemBackground)
        }
    }
}

