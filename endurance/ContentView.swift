//
//  ContentView.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var timerManager: TimerManager
    @Bindable var sessionStore: SessionStore
    @Bindable var presetStore: PresetStore
    
    @AppStorage("selectedTab") private var selectedTab: SidebarTab = .timer
    @State private var isSidebarVisible = true
    @State private var showingAddPreset = false
    @State private var showingEditPreset = false
    @State private var editingPreset: TimerPreset?
    @State private var currentSession: TimerSession?
    
    // Window dimensions (1.5x larger)
    private let mainWidth: CGFloat = 570
    private let mainHeight: CGFloat = 450
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            mainContent
                .frame(width: mainWidth)
            
            // Right sidebar
            if isSidebarVisible {
                IconSidebar(
                    selectedTab: $selectedTab,
                    accentColor: presetColor,
                    onHideSidebar: { 
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            isSidebarVisible = false 
                        }
                    }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .frame(height: mainHeight)
        .background(backgroundView)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10)
        .overlay(alignment: .topLeading) {
            // Close button
            Button(action: minimizeWindow) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.dustGray)
                    .frame(width: 24, height: 24)
                    .glassButton(cornerRadius: 12)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .contentShape(Circle())
            .padding(10)
        }
        .overlay(alignment: .topTrailing) {
            // Show sidebar button (when hidden)
            if !isSidebarVisible {
                Button(action: { 
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isSidebarVisible = true 
                    }
                }) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.dustGray)
                        .frame(width: 28, height: 28)
                        .glassButton(cornerRadius: 14)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .padding(10)
            }
        }
        .sheet(isPresented: $showingAddPreset) {
            PresetEditorSheet(
                presetStore: presetStore,
                isPresented: $showingAddPreset,
                editingPreset: nil,
                timerManager: timerManager
            )
        }
        .sheet(isPresented: $showingEditPreset) {
            if let preset = editingPreset {
                PresetEditorSheet(
                    presetStore: presetStore,
                    isPresented: $showingEditPreset,
                    editingPreset: preset,
                    timerManager: timerManager
                )
            }
        }
        .onAppear {
            sessionStore.setModelContext(modelContext)
            setupTimerCallbacks()
        }
    }
    
    // MARK: - Window Management
    private func minimizeWindow() {
        if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "main" }) {
            window.orderOut(nil)
        }
    }
    
    // MARK: - Main Content
    @ViewBuilder
    private var mainContent: some View {
        switch selectedTab {
        case .timer:
            timerView
        case .presets:
            PresetsPanel(
                timerManager: timerManager,
                presetStore: presetStore,
                showingAddPreset: $showingAddPreset,
                showingEditPreset: $showingEditPreset,
                editingPreset: $editingPreset,
                accentColor: presetColor
            )
        case .stats:
            StatsPanel(sessionStore: sessionStore, accentColor: presetColor)
        case .settings:
            SettingsPanel(timerManager: timerManager, sessionStore: sessionStore, accentColor: presetColor)
        }
    }
    
    // MARK: - Timer View
    private var timerView: some View {
        ZStack {
            // Left side controls for Quick Timer (+5/-5 buttons)
            if timerManager.timerMode == .quickTimer && timerManager.state == .idle {
                VStack(spacing: 10) {
                    Button(action: { timerManager.adjustQuickTimerDuration(by: 5 * 60) }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(presetColor)
                            .frame(width: 32, height: 32)
                            .glassButton(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                    .help("+5 minutes")
                    
                    QuickTimerInputView(
                        duration: Binding(
                            get: { 5 * 60 }, // Dummy binding for display/input logic, specialized for increment
                            set: { newValue in
                                // When user types a value, WE SET THE TIMER DURATION directly
                                timerManager.quickTimerDuration = newValue
                            }
                        ),
                        color: Theme.accentGlow,
                        isInputOnly: true
                    )
                    
                    Button(action: { timerManager.adjustQuickTimerDuration(by: -5 * 60) }) {
                        Image(systemName: "minus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(presetColor)
                            .frame(width: 32, height: 32)
                            .glassButton(cornerRadius: 16)
                    }
                    .buttonStyle(.plain)
                    .help("-5 minutes")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 24)
            }
            
            // Main content (centered)
            VStack(spacing: 0) {
                // Consistent header height for both modes
                Group {
                    if timerManager.timerMode == .pomodoro {
                        HStack(spacing: 6) {
                            Image(systemName: timerManager.currentPreset.icon.rawValue)
                                .font(.system(size: 11, weight: .medium))
                            Text(timerManager.currentPreset.name)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(presetColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(presetColor.opacity(0.15))
                        )
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "stopwatch")
                                .font(.system(size: 11, weight: .medium))
                            Text(formatDuration(timerManager.quickTimerDuration))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(presetColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(presetColor.opacity(0.15))
                        )
                    }
                }
                .frame(height: 30) // Fixed header height
                .padding(.top, 20)
                
                Spacer()
                
                // Timer Ring
                TimerRingView(
                    progress: timerManager.progress,
                    remainingTime: timerManager.formattedTime,
                    isRunning: timerManager.isRunning,
                    phase: timerManager.currentPhase
                )
                
                // Session dots (below timer, only for Pomodoro mode) - fixed height placeholder
                Group {
                    if timerManager.timerMode == .pomodoro {
                        HStack(spacing: 6) {
                            ForEach(0..<timerManager.numberOfSessions, id: \.self) { index in
                                Circle()
                                    .fill(index < timerManager.completedFocusSessions ? presetColor : Theme.dimGray.opacity(0.4))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    } else {
                        // Placeholder to maintain layout
                        Color.clear
                    }
                }
                .frame(height: 24) // Fixed height for dots area
                .padding(.top, 8)
                
                Spacer()
                
                // Controls area with mode toggle button on left
                ZStack {
                // Mode toggle on left (absolute position)
                if timerManager.state == .idle && !timerManager.awaitingBreakStart {
                    HStack {
                        Button(action: {
                            if timerManager.timerMode == .pomodoro {
                                timerManager.setTimerMode(.quickTimer)
                            } else {
                                timerManager.setTimerMode(.pomodoro)
                            }
                        }) {
                            Image(systemName: timerManager.timerMode == .pomodoro ? "timer" : "stopwatch")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(presetColor)
                                .frame(width: 36, height: 36)
                                .glassButton(cornerRadius: 18)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Circle())
                        .help(timerManager.timerMode == .pomodoro ? "Switch to Quick Timer" : "Switch to Pomodoro")
                        .padding(.leading, 24)
                        
                        Spacer()
                    }
                }
                
                // Centered controls
                if timerManager.awaitingBreakStart {
                    VStack(spacing: 12) {
                        Button(action: { timerManager.startBreak() }) {
                            HStack(spacing: 8) {
                                Image(systemName: timerManager.currentPhase.sfSymbol)
                                Text("Start Break")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(phaseColor)
                            )
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { 
                            timerManager.currentPhase = .focus
                            timerManager.awaitingBreakStart = false
                            timerManager.remainingTime = timerManager.totalDuration
                        }) {
                            Text("Skip Break")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.dustGray)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    HStack(spacing: 16) {
                        ControlsView(timerManager: timerManager, accentColor: presetColor)
                        
                        // Skip button when in break and running
                        if timerManager.timerMode == .pomodoro && timerManager.isBreak && (timerManager.isRunning || timerManager.isPaused) {
                            Button(action: { timerManager.skipToNextPhase() }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(presetColor)
                                    .frame(width: 36, height: 36)
                                    .glassButton(cornerRadius: 18)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Circle())
                            .help("Skip to focus")
                        }
                    }
                }
                } // Close controls ZStack
                .padding(.bottom, 24)
            } // Close VStack (main content)
        } // Close outer ZStack
        // Spacebar shortcut for play/pause
        .onKeyPress(.space) {
            togglePlayPause()
            return .handled
        }
    }
    
    // MARK: - Toggle Play/Pause (Spacebar shortcut)
    private func togglePlayPause() {
        if timerManager.awaitingBreakStart {
            timerManager.startBreak()
        } else if timerManager.isRunning {
            timerManager.pause()
        } else if timerManager.isPaused {
            timerManager.resume()
        } else {
            timerManager.start()
        }
    }
    
    // MARK: - App Accent Color (changes based on phase)
    private var presetColor: Color {
        return timerManager.currentPhase == .break ? Theme.breakAccent : Theme.accentGlow
    }
    
    // MARK: - Format Duration (for Quick Timer header)
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 {
            let hours = mins / 60
            let remainingMins = mins % 60
            return remainingMins > 0 ? "\(hours)h \(remainingMins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
    
    // MARK: - Phase Color (for timer ring)
    private var phaseColor: Color {
        return timerManager.currentPhase == .break ? Theme.breakAccent : Theme.accentGlow
    }
    
    // MARK: - Background (Enhanced Transparency)
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Base layer with higher transparency
            if colorScheme == .dark {
                Theme.spaceBlack.opacity(0.6)
            } else {
                Color.white.opacity(0.5)
            }
            
            // Native material with adjusted opacity for transparency control
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
        }
    }
    
    // MARK: - Timer Callbacks
    private func setupTimerCallbacks() {
        // Create session when timer starts
        timerManager.onTimerStart = { [self] in
            // Track focus sessions and quick timer sessions
            if timerManager.currentPhase == .focus || timerManager.timerMode == .quickTimer {
                let presetName = timerManager.timerMode == .quickTimer 
                    ? "Quick Timer" 
                    : timerManager.currentPreset.name
                currentSession = sessionStore.createSession(
                    duration: timerManager.totalDuration,
                    presetName: presetName
                )
            }
        }
        
        // Complete session when timer finishes
        timerManager.onTimerComplete = { [self] in
            if let session = currentSession {
                sessionStore.completeSession(session)
                currentSession = nil
            }
            sessionStore.refreshStats()
        }
        
        // Handle cancellation
        timerManager.onTimerCancel = { [self] elapsed in
            if let session = currentSession {
                sessionStore.cancelSession(session)
                currentSession = nil
            }
            sessionStore.refreshStats()
        }
    }
}

// MARK: - Quick Timer Duration Picker
struct QuickTimerDurationPicker: View {
    @Binding var duration: TimeInterval
    var accentColor: Color = Theme.accentGlow
    
    @Environment(\.colorScheme) private var colorScheme
    
    private let quickDurations: [TimeInterval] = [
        15 * 60,    // 15 min
        30 * 60,    // 30 min
        45 * 60,    // 45 min
        60 * 60,    // 1 hr
        90 * 60,    // 1.5 hr
        120 * 60    // 2 hr
    ]
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(quickDurations, id: \.self) { d in
                Button(action: { duration = d }) {
                    Text(formatDuration(d))
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(duration == d ? .white : Theme.dustGray)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            duration == d
                                ? Capsule().fill(accentColor.opacity(0.8))
                                : Capsule().fill(Theme.glassBackground)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func formatDuration(_ d: TimeInterval) -> String {
        let minutes = Int(d) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hours)h\(mins)" : "\(hours)h"
        }
        return "\(minutes)m"
    }
}

// MARK: - Quick Timer Input View
// MARK: - Quick Timer Input View
struct QuickTimerInputView: View {
    @Binding var duration: TimeInterval
    let color: Color
    var isInputOnly: Bool = false // Kept for API compatibility, not used in logic
    @State private var text = ""
    @FocusState private var isFocused: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        TextField("", text: $text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(width: 34)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(colorScheme == .dark ? .white : .black, lineWidth: 1)
                    .background(Theme.glassBackground.clipShape(RoundedRectangle(cornerRadius: 6)))
            )
            .textFieldStyle(.plain)
            .focused($isFocused)
            .onSubmit {
                commitChange()
            }
            .onChange(of: isFocused) { _, focused in
                if !focused {
                    commitChange()
                } else {
                    // Select all text when focused
                    text = String(Int(duration / 60))
                }
            }
            .onAppear {
                updateText()
            }
            .onChange(of: duration) { _, _ in
                if !isFocused {
                    updateText()
                }
            }
    }
    
    private func updateText() {
        text = String(Int(duration / 60))
    }
    
    private func commitChange() {
        if let mins = Int(text), mins > 0 {
            duration = TimeInterval(mins * 60)
        } else {
            // Revert if invalid
            updateText()
        }
    }
}
