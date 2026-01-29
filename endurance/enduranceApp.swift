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
            MenuBarContentView(timerManager: timerManager, presetStore: presetStore, appDelegate: appDelegate)
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

// MARK: - Menu Bar Label (ONLY timer text, NO icon)
struct MenuBarLabel: View {
    @Bindable var timerManager: TimerManager
    
    var body: some View {
        if timerManager.isRunning || timerManager.isPaused {
            Text(timerManager.menuBarTime)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .monospacedDigit()
        } else {
            // Minimalist idle state
            Text("⏱")
                .font(.system(size: 12))
        }
    }
}

// MARK: - Menu Bar Content
struct MenuBarContentView: View {
    @Bindable var timerManager: TimerManager
    @Bindable var presetStore: PresetStore
    var appDelegate: AppDelegate
    
    var body: some View {
        VStack(spacing: 0) {
            // Timer status
            if timerManager.isRunning || timerManager.isPaused {
                HStack {
                    Image(systemName: timerManager.currentPreset.icon.rawValue)
                        .font(.system(size: 12))
                    Text(timerManager.formattedTime)
                        .font(.system(size: 18, weight: .medium, design: .monospaced))
                }
                .padding(.vertical, 8)
                
                Divider()
            }
            
            // Quick actions
            Button(action: { timerManager.toggle() }) {
                Label(
                    timerManager.isRunning ? "Pause" : (timerManager.isPaused ? "Resume" : "Start"),
                    systemImage: timerManager.isRunning ? "pause.fill" : "play.fill"
                )
            }
            .keyboardShortcut("p", modifiers: [.command])
            
            if !timerManager.isIdle {
                Button(action: { timerManager.reset() }) {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            
            Divider()
            
            // Quick presets
            Menu("Quick Start") {
                ForEach(presetStore.allPresets.prefix(6)) { preset in
                    Button(action: {
                        timerManager.setPreset(preset)
                        timerManager.start()
                    }) {
                        Label("\(preset.name) - \(preset.formattedDuration)", systemImage: preset.icon.rawValue)
                    }
                }
            }
            
            Divider()
            
            // Open main window at last position
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
}
