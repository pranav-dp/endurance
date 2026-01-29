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
    
    weak var timerManager: TimerManager?
    
    // MARK: - App Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalHotkey()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // MARK: - Menu Bar Update
    func updateMenuBarTitle(_ time: String) {
        // Handled by SwiftUI
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
        
        // Restore last position if available, otherwise center
        if let lastPos = lastWindowPosition {
            window.setFrameOrigin(lastPos)
        } else {
            window.center()
        }
        
        // Ensure window level is appropriate (standard or floating)
        // .floating keeps it above other windows, which might be why user thought it "auto closed" if it went behind?
        // But user said "automatically closed". Usually menu bar apps are .floating or .statusBar (popovers).
        // If I replicate CMD+W behavior, standard behavior is better?
        // User wants it to "live in the menu bar".
        // Let's stick to .floating to ensure it doesn't get lost, but REMOVE click-outside auto-close.
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
        window.hasShadow = false // Disable system shadow to prevent borders, using SwiftUI shadow instead
        
        // Remove title bar and borders
        window.styleMask = [.borderless, .fullSizeContentView] 
        window.isMovableByWindowBackground = true
        
        // Ensure it behaves like a proper window
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }
    
    // MARK: - Global Hotkey (CMD + Shift + T)
    private func setupGlobalHotkey() {
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers: NSEvent.ModifierFlags = [.command, .shift]
            let hasModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifiers)
            let isT = event.keyCode == kVK_ANSI_T
            
            if hasModifiers && isT {
                Task { @MainActor in
                    self?.toggleWindow()
                }
            }
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let modifiers: NSEvent.ModifierFlags = [.command, .shift]
            let hasModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(modifiers)
            let isT = event.keyCode == kVK_ANSI_T
            
            if hasModifiers && isT {
                Task { @MainActor in
                    self?.toggleWindow()
                }
                return nil
            }
            return event
        }
    }
}
