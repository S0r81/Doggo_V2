//
//  HapticManager.swift
//  Doggo
//
//  Created by Sorest on 1/6/26.
//

import UIKit

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    // For button taps, toggles, checkmarks
    func impact(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare() // Wakes up the haptic engine
        generator.impactOccurred()
    }
    
    // For success/error/warning events (like finishing a workout)
    func notification(type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

