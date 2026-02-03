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
    
    @State private var selectedTab: SidebarTab = .timer
    @State private var isSidebarVisible = true
    @State private var showingAddPreset = false
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
            AddPresetSheet(presetStore: presetStore, isPresented: $showingAddPreset)
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
        VStack(spacing: 0) {
            // Preset indicator (shows selected preset with appropriate color)
            HStack {
                Spacer()
                
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
                
                Spacer()
            }
            .padding(.top, 16)
            
            // Session counter (only show for Pomodoro workflow)
            if timerManager.completedFocusSessions > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<timerManager.sessionsUntilLongBreak, id: \.self) { index in
                        Circle()
                            .fill(index < timerManager.completedFocusSessions ? presetColor : Theme.dimGray.opacity(0.4))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Timer Ring
            TimerRingView(
                progress: timerManager.progress,
                remainingTime: timerManager.formattedTime,
                isRunning: timerManager.isRunning,
                phase: timerManager.currentPhase
            )
            
            Spacer()
            
            // Controls or Start Break button
            if timerManager.awaitingBreakStart {
                VStack(spacing: 12) {
                    Button(action: { timerManager.startBreak() }) {
                        HStack(spacing: 8) {
                            Image(systemName: timerManager.currentPhase.sfSymbol)
                            Text("Start \(timerManager.currentPhase == .longBreak ? "Long " : "")Break")
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
                .padding(.bottom, 24)
            } else {
                HStack(spacing: 16) {
                    ControlsView(timerManager: timerManager, accentColor: presetColor)
                    
                    // Skip button when in break and running
                    if timerManager.isBreak && (timerManager.isRunning || timerManager.isPaused) {
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
                .padding(.bottom, 24)
            }
        }
    }
    
    // MARK: - App Accent Color (changes based on phase OR preset)
    // If timer is in break phase, return green. If preset is break/rest, return green. Otherwise blue.
    private var presetColor: Color {
        // First check if we're in a break phase (Pomodoro auto-transition)
        if timerManager.currentPhase != .focus {
            return timerManager.currentPhase == .longBreak ? Theme.restAccent : Theme.breakAccent
        }
        
        // Otherwise check if the preset is a break/rest type
        let name = timerManager.currentPreset.name.lowercased()
        if name.contains("break") || name.contains("rest") {
            return Theme.breakAccent
        }
        return Theme.accentGlow
    }
    
    // MARK: - Phase Color (for timer ring)
    private var phaseColor: Color {
        switch timerManager.currentPhase {
        case .focus: return Theme.accentGlow
        case .shortBreak: return Theme.breakAccent
        case .longBreak: return Theme.restAccent
        }
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
        // Create session when timer starts (FIX for stats not working)
        timerManager.onTimerStart = { [self] in
            // Only create sessions for focus periods
            if timerManager.currentPhase == .focus {
                currentSession = sessionStore.createSession(
                    duration: timerManager.totalDuration,
                    presetName: timerManager.currentPreset.name
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
