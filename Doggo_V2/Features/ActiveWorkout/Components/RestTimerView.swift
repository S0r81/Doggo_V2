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

    // Collapsed/expanded preference persists across rest periods, so a lifter
    // who tucks it away keeps it tucked away on the next set.
    @AppStorage("restTimerExpanded") private var isExpanded: Bool = true

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if isExpanded {
                expandedTimer
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            } else {
                collapsedPill
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: isExpanded ? .center : .trailing)
        .padding(.horizontal)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: isExpanded)
    }

    // MARK: - Collapsed (PiP pill)

    private var collapsedPill: some View {
        Button(action: expand) {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.caption)
                Text(formatSeconds(seconds))
                    .monospacedDigit()
                    .bold()
                    .font(.callout)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: seconds)
                Image(systemName: "chevron.up")
                    .font(.caption2.bold())
                    .opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.9), in: Capsule())
            .shadow(radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Rest timer \(formatSeconds(seconds)). Double tap to expand.")
    }

    // MARK: - Expanded (full controls)

    private var expandedTimer: some View {
        VStack(spacing: 12) {
            // SECTION 1: Time Display + collapse handle
            ZStack {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                    Text(formatSeconds(seconds))
                        .monospacedDigit()
                        .bold()
                        .font(.title2)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.snappy, value: seconds)
                }
                .foregroundStyle(.white)

                // Collapse to the PiP pill.
                HStack {
                    Spacer()
                    Button(action: collapse) {
                        Image(systemName: "chevron.down")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Color.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Collapse rest timer")
                }
            }

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
                .accessibilityLabel("Skip rest")
                .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(30)
        .shadow(radius: 10)
    }

    // MARK: - Expand / Collapse

    private func expand() {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isExpanded = true
        }
    }

    private func collapse() {
        HapticManager.shared.impact(style: .light)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            isExpanded = false
        }
    }

    // MARK: - Helper Methods

    private func setPreset(_ duration: Int) {
        // Play audio feedback
        AudioManager.shared.playPresetSelectedSound()
        
        // Play haptic feedback
        HapticManager.shared.impact(style: .medium)
        
        // Update visual state
        withAnimation(.snappy) {
            lastPresetUsed = duration
        }

        // Call the preset callback
        onSetPreset(duration)

        // Reset the highlight after 1s — Task is structured concurrency,
        // unlike the old asyncAfter which could fire against a stale view.
        Task {
            try? await Task.sleep(for: .seconds(1))
            withAnimation(.snappy) {
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

