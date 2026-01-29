//
//  MenuBarView.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

struct MenuBarView: View {
    @Bindable var timerManager: TimerManager
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: timerManager.isRunning ? "timer" : "timer")
                .font(.system(size: 12, weight: .medium))
            
            if timerManager.isRunning || timerManager.isPaused {
                Text(timerManager.menuBarTime)
                    .font(Typography.menuBar)
                    .monospacedDigit()
            }
        }
    }
}

#Preview {
    MenuBarView(timerManager: TimerManager())
}
