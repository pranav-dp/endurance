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
    case `break` = "Break"
    
    var sfSymbol: String {
        switch self {
        case .focus: return "book.fill"
        case .break: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Timer Mode
enum TimerMode: String, Equatable {
    case pomodoro = "Pomodoro"
    case quickTimer = "Quick Timer"
    
    var sfSymbol: String {
        switch self {
        case .pomodoro: return "timer"
        case .quickTimer: return "stopwatch"
        }
    }
}

@MainActor
@Observable
final class TimerManager {
    // MARK: - Timer Mode
    var timerMode: TimerMode = .pomodoro
    
    // MARK: - Published State
    var state: TimerState = .idle
    var remainingTime: TimeInterval = 25 * 60
    var currentPreset: TimerPreset = .classicPomodoro
    
    // MARK: - Quick Timer Mode
    var quickTimerDuration: TimeInterval = 30 * 60 {
        didSet {
            UserDefaults.standard.set(quickTimerDuration, forKey: "quickTimerDuration")
            // Update remaining time if we are in Quick Timer mode and idle
            if timerMode == .quickTimer && state == .idle {
                remainingTime = quickTimerDuration
            }
        }
    }
    
    // MARK: - Pomodoro Phase System
    var currentPhase: TimerPhase = .focus
    var currentSessionIndex: Int = 0  // 0-based index of current focus session
    var awaitingBreakStart: Bool = false
    
    // MARK: - Settings (persisted separately from preset)
    private var _soundEnabled: Bool
    private var _notificationsEnabled: Bool
    private var _autoStartBreaks: Bool
    private var _autoStartFocus: Bool
    
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
    
    var autoStartBreaks: Bool {
        get { _autoStartBreaks }
        set {
            _autoStartBreaks = newValue
            UserDefaults.standard.set(newValue, forKey: "autoStartBreaks")
        }
    }
    
    var autoStartFocus: Bool {
        get { _autoStartFocus }
        set {
            _autoStartFocus = newValue
            UserDefaults.standard.set(newValue, forKey: "autoStartFocus")
        }
    }
    
    // MARK: - Computed Properties
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }
    
    var totalDuration: TimeInterval {
        if timerMode == .quickTimer {
            return quickTimerDuration
        }
        
        switch currentPhase {
        case .focus:
            return currentPreset.focusDuration
        case .break:
            return currentPreset.breakDuration
        }
    }
    
    var formattedTime: String {
        let totalSeconds = Int(remainingTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var menuBarTime: String {
        let totalSeconds = Int(remainingTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var isRunning: Bool { state == .running }
    var isPaused: Bool { state == .paused }
    var isIdle: Bool { state == .idle }
    var isBreak: Bool { currentPhase == .break }
    
    /// Number of focus sessions in current preset
    var numberOfSessions: Int {
        currentPreset.numberOfSessions
    }
    
    /// Number of completed focus sessions (0-based index converted to count)
    var completedFocusSessions: Int {
        currentSessionIndex
    }
    
    // MARK: - Private State
    private var timer: Timer?
    private var startTime: Date?
    private var pausedRemainingTime: TimeInterval = 0
    private var sleepTime: Date?
    
    // MARK: - Callbacks
    var onTimerStart: (() -> Void)?
    var onTimerComplete: (() -> Void)?
    var onTimerCancel: ((TimeInterval) -> Void)?
    var onTick: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        let defaults = UserDefaults.standard
        
        _soundEnabled = defaults.object(forKey: "soundEnabled") == nil ? true : defaults.bool(forKey: "soundEnabled")
        _notificationsEnabled = defaults.object(forKey: "notificationsEnabled") == nil ? true : defaults.bool(forKey: "notificationsEnabled")
        _autoStartBreaks = defaults.object(forKey: "autoStartBreaks") == nil ? true : defaults.bool(forKey: "autoStartBreaks")
        _autoStartFocus = defaults.object(forKey: "autoStartFocus") == nil ? true : defaults.bool(forKey: "autoStartFocus")
        
        // Load saved timer mode
        if let modeString = defaults.string(forKey: "timerMode"),
           let mode = TimerMode(rawValue: modeString) {
            timerMode = mode
        }
        
        // Load quick timer duration
        let savedQuickDuration = defaults.double(forKey: "quickTimerDuration")
        if savedQuickDuration > 0 {
            quickTimerDuration = savedQuickDuration
        }
        
        // Load last used preset
        if let savedPresetData = defaults.data(forKey: "lastUsedPreset"),
           let savedPreset = try? JSONDecoder().decode(TimerPreset.self, from: savedPresetData) {
            currentPreset = savedPreset
        }
        
        // Initialize remaining time based on mode
        if timerMode == .quickTimer {
            remainingTime = quickTimerDuration
        } else {
            remainingTime = currentPreset.focusDuration
        }
        
        setupNotifications()
        requestNotificationPermission()
    }
    
    // MARK: - Mode Control
    func setTimerMode(_ mode: TimerMode) {
        guard state == .idle else { return }
        
        timerMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "timerMode")
        
        if mode == .quickTimer {
            remainingTime = quickTimerDuration
            currentPhase = .focus
        } else {
            remainingTime = currentPreset.focusDuration
            currentPhase = .focus
        }
        
        currentSessionIndex = 0
        awaitingBreakStart = false
    }
    
    func setQuickTimerDuration(_ duration: TimeInterval) {
        quickTimerDuration = duration
        UserDefaults.standard.set(duration, forKey: "quickTimerDuration")
        
        if timerMode == .quickTimer && state == .idle {
            remainingTime = duration
        }
    }
    
    func adjustQuickTimerDuration(by seconds: TimeInterval) {
        let newDuration = max(60, quickTimerDuration + seconds)
        setQuickTimerDuration(newDuration)
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
        
        if elapsed > 0 {
            onTimerCancel?(elapsed)
        }
        
        remainingTime = totalDuration
    }
    
    func skipToNextPhase() {
        guard timerMode == .pomodoro else { return }
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
        
        if let encoded = try? JSONEncoder().encode(preset) {
            UserDefaults.standard.set(encoded, forKey: "lastUsedPreset")
        }
        
        timerMode = .pomodoro
        currentPhase = .focus
        currentSessionIndex = 0
        remainingTime = preset.focusDuration
        pausedRemainingTime = preset.focusDuration
        state = .idle
        awaitingBreakStart = false
    }
    
    // MARK: - Phase Management
    private func transitionToNextPhase() {
        // Quick timer mode: just reset to same duration
        if timerMode == .quickTimer {
            remainingTime = quickTimerDuration
            state = .idle
            return
        }
        
        // Pomodoro mode: cycle through focus/break phases
        switch currentPhase {
        case .focus:
            currentSessionIndex += 1
            
            // Check if all sessions complete
            if currentSessionIndex >= currentPreset.numberOfSessions {
                // Session complete - reset
                currentPhase = .focus
                currentSessionIndex = 0
                remainingTime = currentPreset.focusDuration
                state = .idle
                awaitingBreakStart = false
                return
            }
            
            // More sessions remain - transition to break
            currentPhase = .break
            remainingTime = currentPreset.breakDuration
            state = .idle
            
            if autoStartBreaks {
                start()
            } else {
                awaitingBreakStart = true
            }
            
        case .break:
            // After break: go back to focus
            currentPhase = .focus
            remainingTime = currentPreset.focusDuration
            state = .idle
            
            if autoStartFocus {
                start()
            } else {
                awaitingBreakStart = false
            }
        }
    }
    
    // MARK: - Private Methods
    private func startTimer() {
        stopTimer()
        
        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(timerTick),
            userInfo: nil,
            repeats: true
        )
        
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    @objc private func timerTick() {
        tick()
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
        
        // Track session completion (focus sessions only, or quick timer)
        if currentPhase == .focus || timerMode == .quickTimer {
            onTimerComplete?()
        }
        
        sendCompletionNotification()
        
        if soundEnabled {
            playCompletionSound()
        }
        
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
        
        if timerMode == .quickTimer {
            content.title = "Timer Complete!"
            content.body = "Your timer has finished."
        } else {
            switch currentPhase {
            case .focus:
                content.title = "Focus Session Complete!"
                content.body = "Great work! Time for a break."
            case .break:
                content.title = "Break's Over!"
                content.body = "Ready to focus again?"
            }
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
            self,
            selector: #selector(handleSleep(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWake(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )
    }
    
    @objc private func handleSleep(_ notification: Notification) {
        guard state == .running else { return }
        sleepTime = Date()
        stopTimer()
    }
    
    @objc private func handleWake(_ notification: Notification) {
        guard let sleepTime = sleepTime, state == .running else { 
            self.sleepTime = nil
            return 
        }
        
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
