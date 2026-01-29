//
//  TimerRingView.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

struct TimerRingView: View {
    let progress: Double
    let remainingTime: String
    let isRunning: Bool
    
    // Configurable dimensions
    private let ringSize: CGFloat = 130
    private let ringWidth: CGFloat = 5
    
    var body: some View {
        ZStack {
            // Background glow - more transparent
            Circle()
                .fill(Theme.accentGlow.opacity(isRunning ? 0.08 : 0.03))
                .frame(width: ringSize + 40, height: ringSize + 40)
                .blur(radius: 20)
                .animation(.easeInOut(duration: 1.0), value: isRunning)
            
            // Track circle - subtle and transparent
            Circle()
                .stroke(Theme.glassBorder.opacity(0.1), lineWidth: ringWidth)
                .frame(width: ringSize, height: ringSize)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    Theme.ringGradient,
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accentGlow.opacity(isRunning ? 0.3 : 0), radius: 5, x: 0, y: 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
            
            // Inner progress indicator glow
            Circle()
                .trim(from: progress > 0 ? progress - 0.001 : 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: ringWidth + 2, lineCap: .round))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .blur(radius: 1)
                .opacity(isRunning ? 0.5 : 0)
            
            // Time display
            VStack(spacing: 2) {
                Text(remainingTime)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.starWhite)
                    .shadow(color: .black.opacity(0.1), radius: 2)
            }
        }
    }
}

#Preview {
    TimerRingView(progress: 0.65, remainingTime: "16:15", isRunning: true)
        .padding(50)
        .background(Theme.spaceBlack)
}
