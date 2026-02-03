//
//  TimerManager.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import Foundation
import Combine
import AppKit
import UserNotifications

// MARK: - Timer State
enum TimerState: Equatable {
    case idle
    case running
    case paused
}

// MARK: - Timer Phase
enum TimerPhase: String, Equatable {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
    
    var sfSymbol: String {
        switch self {
        case .focus: return "eye"
        case .shortBreak: return "cup.and.saucer.fill"
        case .longBreak: return "leaf.fill"
        }
    }
}

@MainActor
@Observable
final class TimerManager {
    // MARK: - Published State
    var state: TimerState = .idle
    var remainingTime: TimeInterval = 50 * 60
    var currentPreset: TimerPreset = .deepWork
    var customDuration: TimeInterval = 50 * 60
    
    // MARK: - Pomodoro Phase System
    var currentPhase: TimerPhase = .focus
    var completedFocusSessions: Int = 0
    var awaitingBreakStart: Bool = false
    
    // MARK: - Settings (Stored properties for reactivity, synced to UserDefaults)
    private var _focusDuration: TimeInterval
    private var _shortBreakDuration: TimeInterval
    private var _longBreakDuration: TimeInterval
    private var _sessionsUntilLongBreak: Int
    private var _autoStartBreak: Bool
    private var _soundEnabled: Bool
    private var _notificationsEnabled: Bool
    
    var focusDuration: TimeInterval {
        get { _focusDuration }
        set { 
            _focusDuration = newValue
            UserDefaults.standard.set(newValue, forKey: "focusDuration")
        }
    }
    
    var shortBreakDuration: TimeInterval {
        get { _shortBreakDuration }
        set { 
            _shortBreakDuration = newValue
            UserDefaults.standard.set(newValue, forKey: "shortBreakDuration")
        }
    }
    
    var longBreakDuration: TimeInterval {
        get { _longBreakDuration }
        set { 
            _longBreakDuration = newValue
            UserDefaults.standard.set(newValue, forKey: "longBreakDuration")
        }
    }
    
    var sessionsUntilLongBreak: Int {
        get { _sessionsUntilLongBreak }
        set { 
            _sessionsUntilLongBreak = newValue
            UserDefaults.standard.set(newValue, forKey: "sessionsUntilLongBreak")
        }
    }
    
    var autoStartBreak: Bool {
        get { _autoStartBreak }
        set { 
            _autoStartBreak = newValue
            UserDefaults.standard.set(newValue, forKey: "autoStartBreak")
        }
    }
    
    var soundEnabled: Bool {
        get { _soundEnabled }
        set { 
            _soundEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: "soundEnabled")
        }
    }
    
    var notificationsEnabled: Bool {
        get { _notificationsEnabled }
        set { 
            _notificationsEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: "notificationsEnabled")
        }
    }
    
    // MARK: - Computed Properties
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }
    
    var totalDuration: TimeInterval {
        switch currentPhase {
        case .focus:
            return currentPreset.duration > 0 ? currentPreset.duration : focusDuration
        case .shortBreak:
            return shortBreakDuration
        case .longBreak:
            return longBreakDuration
        }
    }
    
    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var menuBarTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var isIdle: Bool { state == .idle }
    var isBreak: Bool { currentPhase != .focus }
    
    // MARK: - Private State
    private var timer: Timer?
    private var startTime: Date?
    private var pausedRemainingTime: TimeInterval = 0
    private var sleepTime: Date?
    
    // MARK: - Callbacks
    var onTimerStart: (() -> Void)?
    var onTimerComplete: (() -> Void)?
    var onTimerCancel: ((TimeInterval) -> Void)?  // elapsed time
    var onTick: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        // Load from UserDefaults with defaults
        let defaults = UserDefaults.standard
        _focusDuration = defaults.double(forKey: "focusDuration").nonZeroOr(50 * 60)
        _shortBreakDuration = defaults.double(forKey: "shortBreakDuration").nonZeroOr(5 * 60)
        _longBreakDuration = defaults.double(forKey: "longBreakDuration").nonZeroOr(15 * 60)
        
        let sessions = defaults.integer(forKey: "sessionsUntilLongBreak")
        _sessionsUntilLongBreak = sessions > 0 ? sessions : 4
        
        _autoStartBreak = defaults.object(forKey: "autoStartBreak") == nil ? true : defaults.bool(forKey: "autoStartBreak")
        _soundEnabled = defaults.object(forKey: "soundEnabled") == nil ? true : defaults.bool(forKey: "soundEnabled")
        _notificationsEnabled = defaults.object(forKey: "notificationsEnabled") == nil ? true : defaults.bool(forKey: "notificationsEnabled")
        
        remainingTime = _focusDuration
        
        setupNotifications()
        requestNotificationPermission()
    }
    
    // MARK: - Timer Controls
    func start() {
        guard state != .running else { return }
        
        if state == .idle {
            remainingTime = totalDuration
            awaitingBreakStart = false
            onTimerStart?()
        }
        
        startTime = Date()
        pausedRemainingTime = remainingTime
        state = .running
        
        startTimer()
    }
    
    func pause() {
        guard state == .running else { return }
        
        stopTimer()
        pausedRemainingTime = remainingTime
        state = .paused
    }
    
    func resume() {
        guard state == .paused else { return }
        start()
    }
    
    func toggle() {
        switch state {
        case .idle:
            start()
        case .running:
            pause()
        case .paused:
            resume()
        }
    }
    
    func reset() {
        stopTimer()
        remainingTime = totalDuration
        pausedRemainingTime = totalDuration
        state = .idle
        awaitingBreakStart = false
    }
    
    func stop() {
        let elapsed = totalDuration - remainingTime
        stopTimer()
        state = .idle
        
        // Notify about cancellation with elapsed time
        if elapsed > 0 {
            onTimerCancel?(elapsed)
        }
        
        remainingTime = totalDuration
    }
    
    func skipToNextPhase() {
        stopTimer()
        transitionToNextPhase()
    }
    
    func startBreak() {
        guard awaitingBreakStart else { return }
        awaitingBreakStart = false
        start()
    }
    
    // MARK: - Preset Configuration
    func setPreset(_ preset: TimerPreset) {
        let wasRunning = state == .running
        if wasRunning {
            pause()
        }
        
        currentPreset = preset
        customDuration = preset.duration
        currentPhase = .focus
        remainingTime = preset.duration
        pausedRemainingTime = preset.duration
        state = .idle
        awaitingBreakStart = false
    }
    
    func setCustomDuration(_ duration: TimeInterval) {
        customDuration = duration
        if state == .idle && currentPhase == .focus {
            remainingTime = duration
        }
    }
    
    // MARK: - Phase Management
    private func transitionToNextPhase() {
        switch currentPhase {
        case .focus:
            completedFocusSessions += 1
            
            // Determine break type
            if completedFocusSessions >= sessionsUntilLongBreak {
                currentPhase = .longBreak
                completedFocusSessions = 0
            } else {
                currentPhase = .shortBreak
            }
            
            remainingTime = totalDuration
            state = .idle
            
            // Auto-start break or wait for user
            if autoStartBreak {
                start()
            } else {
                awaitingBreakStart = true
            }
            
        case .shortBreak, .longBreak:
            currentPhase = .focus
            remainingTime = currentPreset.duration > 0 ? currentPreset.duration : focusDuration
            state = .idle
            awaitingBreakStart = false
        }
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
        
        // Use common run loop mode for menu bar updates
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func tick() {
        guard state == .running, let startTime = startTime else { return }
        
        let elapsed = Date().timeIntervalSince(startTime)
        remainingTime = max(0, pausedRemainingTime - elapsed)
        
        onTick?()
        
        if remainingTime <= 0 {
            complete()
        }
    }
    
    private func complete() {
        stopTimer()
        state = .idle
        remainingTime = 0
        
        // Only count focus sessions for stats
        if currentPhase == .focus {
            onTimerComplete?()
        }
        
        // Send notification
        sendCompletionNotification()
        
        // Play sound
        if soundEnabled {
            playCompletionSound()
        }
        
        // Transition to next phase
        transitionToNextPhase()
    }
    
    private func playCompletionSound() {
        NSSound(named: "Glass")?.play()
    }
    
    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    private func sendCompletionNotification() {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        
        switch currentPhase {
        case .focus:
            content.title = "Focus Session Complete! 🎉"
            content.body = "Great work! Time for a break."
        case .shortBreak, .longBreak:
            content.title = "Break's Over! 💪"
            content.body = "Ready to focus again?"
        }
        
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Sleep/Wake Handling
    private func setupNotifications() {
        let workspace = NSWorkspace.shared
        let notificationCenter = workspace.notificationCenter
        
        notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleSleep()
            }
        }
        
        notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWake()
            }
        }
    }
    
    private func handleSleep() {
        guard state == .running else { return }
        sleepTime = Date()
        stopTimer()
    }
    
    private func handleWake() {
        guard let sleepTime = sleepTime, state == .running else { 
            self.sleepTime = nil
            return 
        }
        
        // Calculate time elapsed during sleep
        let sleepDuration = Date().timeIntervalSince(sleepTime)
        remainingTime = max(0, remainingTime - sleepDuration)
        pausedRemainingTime = remainingTime
        startTime = Date()
        
        self.sleepTime = nil
        
        if remainingTime <= 0 {
            complete()
        } else {
            startTimer()
        }
    }
}

// MARK: - Helper Extension
private extension Double {
    func nonZeroOr(_ defaultValue: Double) -> Double {
        return self > 0 ? self : defaultValue
    }
}
