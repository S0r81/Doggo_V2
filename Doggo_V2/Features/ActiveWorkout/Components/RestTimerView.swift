//
//  RestTimerView.swift
//  Doggo
//
//  Created by Sorest on 1/5/26.
//  Updated: 1/20/26 - Added preset buttons and audio feedback
//

import SwiftUI

struct RestTimerView: View {
    let seconds: Int
    var onAdd: () -> Void
    var onSkip: () -> Void
    
    // NEW: Preset timer callback
    var onSetPreset: (Int) -> Void
    
    // Track which preset was last used for visual feedback
    @State private var lastPresetUsed: Int?
    
    var body: some View {
        VStack(spacing: 12) {
            // SECTION 1: Time Display
            HStack(spacing: 4) {
                Image(systemName: "timer")
                    .font(.caption)
                Text(formatSeconds(seconds))
                    .monospacedDigit()
                    .bold()
                    .font(.title2)
            }
            .foregroundStyle(.white)
            
            // SECTION 2: Preset Buttons Row
            HStack(spacing: 8) {
                PresetButton(duration: 60, currentSeconds: seconds, lastUsed: lastPresetUsed) {
                    setPreset(60)
                }
                
                PresetButton(duration: 90, currentSeconds: seconds, lastUsed: lastPresetUsed) {
                    setPreset(90)
                }
                
                PresetButton(duration: 120, currentSeconds: seconds, lastUsed: lastPresetUsed) {
                    setPreset(120)
                }
            }
            
            // SECTION 3: Control Buttons Row
            HStack(spacing: 12) {
                // +30s Button (Existing)
                Button(action: onAdd) {
                    Text("+30s")
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(6)
                }
                .foregroundStyle(.white)
                
                // Skip Button (Existing)
                Button(action: onSkip) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .padding(8)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(30)
        .shadow(radius: 10)
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func setPreset(_ duration: Int) {
        // Play audio feedback
        AudioManager.shared.playPresetSelectedSound()
        
        // Play haptic feedback
        HapticManager.shared.impact(style: .medium)
        
        // Update visual state
        withAnimation {
            lastPresetUsed = duration
        }
        
        // Call the preset callback
        onSetPreset(duration)
        
        // Reset visual indicator after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation {
                lastPresetUsed = nil
            }
        }
    }
    
    private func formatSeconds(_ total: Int) -> String {
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Preset Button Component

struct PresetButton: View {
    let duration: Int
    let currentSeconds: Int
    let lastUsed: Int?
    let action: () -> Void
    
    private var isActive: Bool {
        lastUsed == duration
    }
    
    private var label: String {
        if duration >= 60 {
            return "\(duration / 60)m"
        } else {
            return "\(duration)s"
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .bold()
                .foregroundStyle(isActive ? .black : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isActive ? Color.white : Color.white.opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        
        VStack(spacing: 40) {
            // Active timer
            RestTimerView(
                seconds: 75,
                onAdd: {},
                onSkip: {},
                onSetPreset: { _ in }
            )
            
            // Almost done timer
            RestTimerView(
                seconds: 5,
                onAdd: {},
                onSkip: {},
                onSetPreset: { _ in }
            )
        }
    }
}

