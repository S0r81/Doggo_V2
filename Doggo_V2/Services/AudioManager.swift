//
//  AudioManager.swift
//  Doggo
//
//  Created by Assistant on 1/20/26.
//

import AVFoundation
import UIKit

class AudioManager {
    static let shared = AudioManager()
    
    private init() {}
    
    // MARK: - Audio Alert Sounds
    
    /// Plays an alert sound when the rest timer completes
    /// Respects the user's audio alert preference from UserDefaults
    func playTimerCompletionAlert() {
        // Check if audio alerts are enabled
        guard UserDefaults.standard.bool(forKey: "audioAlertsEnabled") else { return }
        
        // System Sound IDs:
        // 1013 = "Tock" (Timer sound)
        // 1307 = "Tink" (Light notification)
        // 1315 = "Anticipate" (Rising tone)
        // 1023 = "Fanfare" (Completion sound)
        
        // Using "Tock" - similar to default iOS timer sound
        AudioServicesPlaySystemSound(1013)
    }
    
    /// Plays a subtle tick sound during countdown (last 3 seconds)
    /// Used for optional countdown feature
    func playCountdownTick() {
        // Check if countdown ticks are enabled
        guard UserDefaults.standard.bool(forKey: "countdownTicksEnabled") else { return }
        
        // Using "Tock" at lower volume conceptually (system sounds don't have volume control)
        // Alternative: 1104 = "Tock" (softer variant)
        AudioServicesPlaySystemSound(1104)
    }
    
    // MARK: - Preset Button Feedback
    
    /// Plays a quick feedback sound when preset buttons are tapped
    /// This is separate from completion alerts
    func playPresetSelectedSound() {
        // Light tap sound for immediate feedback
        // 1519 = "WheelsOfTime" (subtle click)
        AudioServicesPlaySystemSound(1519)
    }
    
    // MARK: - Utility Methods
    
    /// Checks if audio alerts are currently enabled
    var isAudioEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "audioAlertsEnabled")
    }
    
    /// Checks if countdown ticks are currently enabled
    var areCountdownTicksEnabled: Bool {
        return UserDefaults.standard.bool(forKey: "countdownTicksEnabled")
    }
    
    /// Sets audio alert preference
    /// - Parameter enabled: Whether audio alerts should play
    func setAudioAlerts(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "audioAlertsEnabled")
    }
    
    /// Sets countdown tick preference
    /// - Parameter enabled: Whether countdown ticks should play
    func setCountdownTicks(enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "countdownTicksEnabled")
    }
}

// MARK: - System Sound Reference Guide

/*
 Common iOS System Sound IDs (for reference):
 
 ALERTS & NOTIFICATIONS:
 - 1013 = "Tock" (Timer sound - RECOMMENDED for completion)
 - 1307 = "Tink" (Light notification)
 - 1315 = "Anticipate" (Rising tone)
 - 1023 = "Fanfare" (Completion/celebration)
 - 1005 = "New Mail" (Classic alert)
 
 SUBTLE SOUNDS:
 - 1104 = "Tock" (Softer variant)
 - 1519 = "WheelsOfTime" (Subtle click - RECOMMENDED for presets)
 - 1306 = "Tink" variation
 
 VIBRATIONS ONLY:
 - 4095 = Standard vibration (fallback if silent mode)
 
 Note: System sounds automatically respect:
 - Device silent mode
 - Volume settings
 - Do Not Disturb mode
 
 They do NOT respect:
 - Individual app volume (uses system volume)
 
 To test sounds, use:
 AudioServicesPlaySystemSound(SOUND_ID)
 
 To play with vibration:
 AudioServicesPlayAlertSound(SOUND_ID)
*/

