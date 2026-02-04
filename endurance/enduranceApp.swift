//
//  enduranceApp.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI
import SwiftData
import AppKit

@main
struct EnduranceApp: App {
    // MARK: - State Objects
    @State private var timerManager = TimerManager()
    @State private var sessionStore = SessionStore()
    @State private var presetStore = PresetStore()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - SwiftData Container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TimerSession.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        // Main window
        Window("Endurance", id: "main") {
            ContentView(
                timerManager: timerManager,
                sessionStore: sessionStore,
                presetStore: presetStore
            )
            .onAppear {
                configureMainWindow()
            }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultPosition(.center)
        .modelContainer(sharedModelContainer)
        
        // Menu bar - ONLY timer, no icon
        MenuBarExtra {
            MenuBarContentView(
                timerManager: timerManager, 
                presetStore: presetStore, 
                sessionStore: sessionStore,
                appDelegate: appDelegate
            )
        } label: {
            MenuBarLabel(timerManager: timerManager)
        }
        .menuBarExtraStyle(.menu)
    }
    
    // MARK: - Configuration
    private func configureMainWindow() {
        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
                appDelegate.setMainWindow(window)
                appDelegate.timerManager = timerManager
            }
        }
    }
}

// MARK: - Menu Bar Label (with preset/mode icon)
struct MenuBarLabel: View {
    @Bindable var timerManager: TimerManager
    
    private var displayIcon: String {
        // When in a break, show break icon
        if timerManager.currentPhase != .focus && (timerManager.isRunning || timerManager.isPaused || timerManager.awaitingBreakStart) {
            return timerManager.currentPhase.sfSymbol
        }
        // For focus or idle, show mode-appropriate icon
        if timerManager.timerMode == .pomodoro {
            return timerManager.currentPreset.icon.rawValue
        } else {
            return "stopwatch"
        }
    }
    
    var body: some View {
        if timerManager.isRunning || timerManager.isPaused {
            HStack(spacing: 4) {
                Image(systemName: displayIcon)
                    .font(.system(size: 11))
                Text(timerManager.menuBarTime)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
        } else if timerManager.awaitingBreakStart {
            HStack(spacing: 4) {
                Image(systemName: displayIcon)
                    .font(.system(size: 11))
                Text("Break")
                    .font(.system(size: 12, weight: .medium))
            }
        } else {
            // Idle: show preset icon for Pomodoro, stopwatch for Quick Timer
            Image(systemName: displayIcon)
                .font(.system(size: 12))
        }
    }
}

// MARK: - Menu Bar Content
struct MenuBarContentView: View {
    @Bindable var timerManager: TimerManager
    @Bindable var presetStore: PresetStore
    @Bindable var sessionStore: SessionStore
    var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Timer status
            if timerManager.isRunning || timerManager.isPaused || timerManager.awaitingBreakStart {
                VStack(spacing: 4) {
                    HStack {
                        Image(systemName: timerManager.currentPhase.sfSymbol)
                        Text(timerManager.currentPhase.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    
                    if !timerManager.awaitingBreakStart {
                        Text(timerManager.formattedTime)
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                    }
                }
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Daily progress
            if let todayStats = sessionStore.todayStats {
                HStack {
                    Image(systemName: "target")
                    Text("Today: \(formatTime(todayStats.totalFocusTime)) / \(formatTime(Double(sessionStore.dailyGoalMinutes) * 60))")
                        .font(.system(size: 12))
                }
                .padding(.vertical, 6)
                
                Divider()
            }
            
            // Quick actions
            if timerManager.awaitingBreakStart {
                Button(action: { timerManager.startBreak() }) {
                    Label("Start Break", systemImage: "play.fill")
                }
                
                Button(action: { 
                    timerManager.currentPhase = .focus
                    timerManager.awaitingBreakStart = false
                    timerManager.remainingTime = timerManager.totalDuration
                }) {
                    Label("Skip Break", systemImage: "forward.fill")
                }
            } else {
                Button(action: { timerManager.toggle() }) {
                    Label(
                        timerManager.isRunning ? "Pause" : (timerManager.isPaused ? "Resume" : "Start"),
                        systemImage: timerManager.isRunning ? "pause.fill" : "play.fill"
                    )
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                
                if !timerManager.isIdle {
                    Button(action: { timerManager.reset() }) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    
                    if timerManager.isBreak {
                        Button(action: { timerManager.skipToNextPhase() }) {
                            Label("Skip to Focus", systemImage: "forward.fill")
                        }
                        .keyboardShortcut("s", modifiers: [.command, .shift])
                    }
                }
            }
            
            Divider()
            
            // Session counter
            if timerManager.completedFocusSessions > 0 || timerManager.currentSessionIndex > 0 {
                HStack {
                    ForEach(0..<timerManager.numberOfSessions, id: \.self) { index in
                        Image(systemName: index < timerManager.completedFocusSessions ? "circle.fill" : "circle")
                            .font(.system(size: 8))
                    }
                    Text("\(timerManager.completedFocusSessions)/\(timerManager.numberOfSessions) sessions")
                        .font(.system(size: 11))
                }
                .padding(.vertical, 6)
                
                Divider()
            }
            
            // Quick presets
            Menu("Quick Start") {
                ForEach(Array(presetStore.allPresets.prefix(6)), id: \.id) { preset in
                    Button(action: {
                        timerManager.setPreset(preset)
                        timerManager.start()
                    }) {
                        Label("\(preset.name) • \(preset.summaryDescription)", systemImage: preset.icon.rawValue)
                    }
                }
            }
            
            Divider()
            
            // Open main window
            Button(action: {
                appDelegate.showWindow()
            }) {
                Label("Open Endurance", systemImage: "rectangle.portrait.and.arrow.forward")
            }
            .keyboardShortcut("o", modifiers: [.command])
            
            Divider()
            
            // Quit
            Button(action: { NSApp.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .keyboardShortcut("q", modifiers: [.command])
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
