//
//  RestTimerManager.swift
//  Doggo_V2
//

import SwiftUI
import Combine
import AVFoundation
import UserNotifications
import UIKit

class RestTimerManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    // MARK: - Published State
    @Published var timeRemaining: Int = 0
    @Published var isActive: Bool = false
    @Published var totalDuration: Int = 0
    @Published var progress: Double = 1.0 // Helper for UI progress bars if needed
    
    // MARK: - Private Properties
    private var timer: AnyCancellable?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var endTime: Date? // <--- THE KEY FIX
    
    override init() {
        super.init()
        requestNotificationPermission()
        UNUserNotificationCenter.current().delegate = self
    }
    
    // MARK: - Permissions
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    // MARK: - Actions
    func startTimer(duration: Int) {
        // 1. Set Critical Timestamps
        self.totalDuration = duration
        self.timeRemaining = duration
        self.endTime = Date().addingTimeInterval(TimeInterval(duration)) // Define exactly when it ends
        self.isActive = true
        
        // 2. Audio/Haptics
        HapticManager.shared.notification(type: .success)
        
        // 3. Schedule Notification
        scheduleNotification(seconds: duration)
        
        // 4. Start Background Task (Helps keep it alive slightly longer)
        beginBackgroundTask()
        
        // 5. Start Ticker
        startTicker()
    }
    
    func stopTimer() {
        isActive = false
        endTime = nil // Clear timestamp
        timer?.cancel()
        timer = nil
        endBackgroundTask()
        cancelNotification()
    }
    
    func addTime(_ seconds: Int) {
        guard let currentEnd = endTime else { return }
        
        // Push the end time forward
        self.endTime = currentEnd.addingTimeInterval(TimeInterval(seconds))
        self.totalDuration += seconds
        
        // Update immediate UI
        if let newEnd = self.endTime {
            let diff = Int(newEnd.timeIntervalSince(Date()))
            self.timeRemaining = max(0, diff)
        }
        
        // Reschedule notification
        if isActive {
            cancelNotification()
            scheduleNotification(seconds: timeRemaining)
        }
    }
    
    // MARK: - Logic
    private func startTicker() {
        timer?.cancel()
        // We use .main loop to ensure UI updates are snappy
        timer = Timer.publish(every: 0.1, on: .main, in: .common) // Check more frequently (0.1s)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }
    }
    
    private func tick() {
        guard let endTime = endTime, isActive else { return }
        
        let now = Date()
        let diff = endTime.timeIntervalSince(now)
        let remaining = Int(ceil(diff))
        
        // Only update UI if the second actually changed (prevents jitter)
        if remaining != self.timeRemaining {
            self.timeRemaining = max(0, remaining)
            
            // Audio Feedback for last 3 seconds
            if self.timeRemaining <= 3 && self.timeRemaining > 0 {
                AudioManager.shared.playCountdownTick()
            }
            
            // Timer Finished
            if self.timeRemaining <= 0 {
                finish()
            }
        }
    }
    
    private func finish() {
        stopTimer()
        AudioManager.shared.playTimerCompletionAlert()
        HapticManager.shared.notification(type: .success)
        timeRemaining = 0
    }
    
    // MARK: - Notification Logic
    private func scheduleNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Time Over!"
        content.body = "Time to get back to work. 💪"
        content.sound = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "RestTimer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimer"])
    }
    
    // MARK: - Background Handling
    private func beginBackgroundTask() {
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Delegate (Show banner even if app is open)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // MARK: - Formatting
    var formattedTime: String {
        let minutes = timeRemaining / 60
        let seconds = timeRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
