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
    var phase: TimerPhase = .focus
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulseScale: CGFloat = 1.0
    
    private let ringSize: CGFloat = 180
    private let ringWidth: CGFloat = 6
    
    var body: some View {
        ZStack {
            // Subtle glow for break phases
            if phase != .focus {
                Circle()
                    .fill(phaseColor.opacity(0.15))
                    .frame(width: ringSize + 40, height: ringSize + 40)
                    .blur(radius: 20)
                    .scaleEffect(pulseScale)
            }
            
            // Background ring
            Circle()
                .stroke(Theme.dimGray.opacity(0.2), lineWidth: ringWidth)
                .frame(width: ringSize, height: ringSize)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Theme.ringGradient(for: phase),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            // Glow effect at the TIP of the ring only
            Circle()
                .trim(from: max(0, progress - 0.02), to: progress)
                .stroke(
                    phaseColor,
                    style: StrokeStyle(lineWidth: ringWidth + 8, lineCap: .round)
                )
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.degrees(-90))
                .blur(radius: 6)
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            // Time display - JUST the time, no status text
            Text(remainingTime)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .foregroundStyle(Theme.primaryText(colorScheme))
                .monospacedDigit()
        }
        .onAppear {
            if phase != .focus {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            }
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase != .focus {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    pulseScale = 1.1
                }
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    pulseScale = 1.0
                }
            }
        }
    }
    
    private var phaseColor: Color {
        switch phase {
        case .focus: return Theme.accentGlow
        case .break: return Theme.breakAccent
        }
    }
}

#Preview {
    ZStack {
        Theme.spaceBlack
            .ignoresSafeArea()
        
        VStack(spacing: 40) {
            TimerRingView(progress: 0.65, remainingTime: "12:30", isRunning: true, phase: .focus)
            TimerRingView(progress: 0.3, remainingTime: "03:30", isRunning: true, phase: .break)
        }
    }
    .preferredColorScheme(.dark)
}
