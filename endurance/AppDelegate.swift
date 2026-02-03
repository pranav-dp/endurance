//
//  AppDelegate.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import AppKit
import SwiftUI
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var lastWindowPosition: NSPoint?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    
    weak var timerManager: TimerManager?
    
    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkey()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Window Management
    @objc func toggleWindow() {
        if let window = mainWindow, window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func showWindow() {
        guard let window = mainWindow else { return }
        
        if let lastPos = lastWindowPosition {
            window.setFrameOrigin(lastPos)
        } else {
            window.center()
        }
        
        window.level = .floating 
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideWindow() {
        guard let window = mainWindow else { return }
        lastWindowPosition = window.frame.origin
        window.orderOut(nil)
    }
    
    func setMainWindow(_ window: NSWindow?) {
        mainWindow = window
        configureWindow()
    }
    
    private func configureWindow() {
        guard let window = mainWindow else { return }
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        window.styleMask = [.borderless, .fullSizeContentView] 
        window.isMovableByWindowBackground = true
        
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    // MARK: - Global Hotkeys
    private func setupGlobalHotkey() {
        // Global monitor (when app is not focused)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleHotkey(event)
            }
        }
        
        // Local monitor (when app is focused) - must be synchronous for return value
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event -> NSEvent? in
            guard let self = self else { return event }
            
            let modifiers: NSEvent.ModifierFlags = [.command, .shift]
            let hasModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifiers)
            
            guard hasModifiers else { return event }
            
            switch event.keyCode {
            case UInt16(kVK_ANSI_T):
                Task { @MainActor in self.toggleWindow() }
                return nil
            case UInt16(kVK_ANSI_P):
                Task { @MainActor in self.timerManager?.toggle() }
                return nil
            case UInt16(kVK_ANSI_R):
                Task { @MainActor in self.timerManager?.reset() }
                return nil
            case UInt16(kVK_ANSI_S):
                Task { @MainActor in self.timerManager?.skipToNextPhase() }
                return nil
            default:
                return event
            }
        }
    }
    
    private func handleHotkey(_ event: NSEvent) {
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]
        let hasModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifiers)
        
        guard hasModifiers else { return }
        
        switch event.keyCode {
        case UInt16(kVK_ANSI_T):
            toggleWindow()
        case UInt16(kVK_ANSI_P):
            timerManager?.toggle()
        case UInt16(kVK_ANSI_R):
            timerManager?.reset()
        case UInt16(kVK_ANSI_S):
            timerManager?.skipToNextPhase()
        default:
            break
        }
    }
}
