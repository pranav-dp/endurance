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
    
    // Window dimensions
    private let mainWidth: CGFloat = 380
    private let mainHeight: CGFloat = 300
    
    var body: some View {
        HStack(spacing: 0) {
            // Main content
            mainContent
                .frame(width: mainWidth)
            
            // Right sidebar
            if isSidebarVisible {
                IconSidebar(
                    selectedTab: $selectedTab,
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
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 10) // Slightly softer shadow
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
                showingAddPreset: $showingAddPreset
            )
        case .stats:
            StatsPanel(sessionStore: sessionStore)
        case .settings:
            settingsView
        }
    }
    
    // MARK: - Timer View
    private var timerView: some View {
        VStack(spacing: 0) {
            // Preset indicator
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: timerManager.currentPreset.icon.rawValue)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accentGlow)
                    Text(timerManager.currentPreset.name)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText(colorScheme))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .glassButton(cornerRadius: 16)
                Spacer()
            }
            .padding(.top, 16)
            
            Spacer()
            
            // Timer Ring
            TimerRingView(
                progress: timerManager.progress,
                remainingTime: timerManager.formattedTime,
                isRunning: timerManager.isRunning
            )
            
            Spacer()
            
            // Controls
            ControlsView(timerManager: timerManager)
                .padding(.bottom, 24)
        }
    }
    
    // MARK: - Settings View
    private var settingsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText(colorScheme))
                .padding(.horizontal, 16)
                .padding(.top, 16)
            
            // Sound
            HStack {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accentGlow)
                
                Text("Completion Sound")
                    .font(.system(size: 13, design: .rounded))
                    .foregroundStyle(Theme.primaryText(colorScheme))
                
                Spacer()
                
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .tint(Theme.accentGlow)
            }
            .padding(12)
            .glassButton(cornerRadius: 10)
            .padding(.horizontal, 16)
            
            Spacer()
            
            Text("Endurance v1.0")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.dimGray)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
        }
    }
    
    // MARK: - Background (Enhanced Transparency)
    @ViewBuilder
    private var backgroundView: some View {
        ZStack {
            // Base layer with higher transparency
            if colorScheme == .dark {
                Theme.spaceBlack.opacity(0.6) // Reduced from 0.9
            } else {
                Color.white.opacity(0.5) // Reduced from 0.9
            }
            
            // Native material with adjusted opacity for transparency control
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.85))
        }
    }
    
    private func setupTimerCallbacks() {
        timerManager.onTimerComplete = { [self] in
            if let session = currentSession {
                sessionStore.completeSession(session)
                currentSession = nil
            }
            sessionStore.refreshStats()
        }
    }
}
