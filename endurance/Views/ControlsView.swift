//
//  ControlsView.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

struct ControlsView: View {
    @Bindable var timerManager: TimerManager
    var accentColor: Color = Theme.accentGlow
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 28) {
            // Reset button
            Button(action: { timerManager.reset() }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
                    .frame(width: 44, height: 44)
                    .glassButton(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .opacity(timerManager.isIdle ? 0.4 : 1)
            .disabled(timerManager.isIdle)
            
            // Play/Pause button
            Button(action: { timerManager.toggle() }) {
                ZStack {
                    // Glow
                    Circle()
                        .fill(accentColor.opacity(0.25))
                        .frame(width: 60, height: 60)
                        .blur(radius: 8)
                    
                    // Button
                    Circle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Circle()
                                .stroke(accentColor.opacity(0.4), lineWidth: 1)
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: timerManager.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(.white)
                        .offset(x: timerManager.isRunning ? 0 : 2)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            
            // Stop button
            Button(action: { timerManager.stop() }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
                    .frame(width: 44, height: 44)
                    .glassButton(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .opacity(timerManager.isIdle ? 0.4 : 1)
            .disabled(timerManager.isIdle)
        }
    }
}

#Preview {
    ZStack {
        Theme.spaceBlack
            .ignoresSafeArea()
        
        ControlsView(timerManager: TimerManager())
    }
    .preferredColorScheme(.dark)
}
