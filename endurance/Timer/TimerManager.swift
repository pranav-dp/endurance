//
//  TimerManager.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import Foundation
import Combine
import AppKit

enum TimerState: Equatable {
    case idle
    case running
    case paused
}

@MainActor
@Observable
final class TimerManager {
    // MARK: - Published State
    var state: TimerState = .idle
    var remainingTime: TimeInterval = 25 * 60
    var currentPreset: TimerPreset = .pomodoro
    var customDuration: TimeInterval = 25 * 60
    
    // MARK: - Computed Properties
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return 1 - (remainingTime / totalDuration)
    }
    
    var totalDuration: TimeInterval {
        currentPreset.duration > 0 ? currentPreset.duration : customDuration
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
    
    // MARK: - Private State
    private var timer: Timer?
    private var startTime: Date?
    private var pausedRemainingTime: TimeInterval = 0
    private var sleepTime: Date?
    
    // Callbacks
    var onTimerComplete: (() -> Void)?
    var onTick: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        setupNotifications()
    }
    
    // MARK: - Timer Controls
    func start() {
        guard state != .running else { return }
        
        if state == .idle {
            remainingTime = totalDuration
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
    }
    
    func stop() {
        stopTimer()
        state = .idle
        remainingTime = totalDuration
    }
    
    // MARK: - Preset Configuration
    func setPreset(_ preset: TimerPreset) {
        let wasRunning = state == .running
        if wasRunning {
            pause()
        }
        
        currentPreset = preset
        customDuration = preset.duration
        remainingTime = preset.duration
        pausedRemainingTime = preset.duration
        state = .idle
    }
    
    func setCustomDuration(_ duration: TimeInterval) {
        customDuration = duration
        if state == .idle {
            remainingTime = duration
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
        
        onTimerComplete?()
        playCompletionSound()
    }
    
    private func playCompletionSound() {
        NSSound(named: "Glass")?.play()
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
