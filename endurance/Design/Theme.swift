//
//  Theme.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

// MARK: - Interstellar Color Palette with Enhanced Glassmorphism
enum Theme {
    // Primary backgrounds - highly transparent
    static let spaceBlack = Color(hex: "0A0A0F")
    static let deepSpace = Color(hex: "111118")
    static let cosmicDark = Color(hex: "16161F")
    
    // Glass effect colors - reduced opacity for more transparency
    static let glassBackground = Color.white.opacity(0.04)
    static let glassBorder = Color.white.opacity(0.1)
    static let glassHighlight = Color.white.opacity(0.15)
    
    // Accent colors
    static let stellarBlue = Color(hex: "2E5EAA")
    static let accentGlow = Color(hex: "4A8FE7")
    static let nebulaPurple = Color(hex: "5E4A9E")
    
    // Phase-specific colors
    static let focusAccent = Color(hex: "4A8FE7")   // Blue
    static let breakAccent = Color(hex: "5BA37A")   // Calming green
    static let restAccent = Color(hex: "8B7BB8")    // Relaxing purple
    
    // Text colors
    static let starWhite = Color(hex: "F0F0F5")
    static let dustGray = Color(hex: "8A8A9A")
    static let dimGray = Color(hex: "4A4A5A")
    
    // Status colors
    static let successGreen = Color(hex: "3A9E6A")
    static let warningAmber = Color(hex: "E5A84A")
    
    // Adaptive colors for light/dark mode
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? spaceBlack : Color(hex: "F5F5FA")
    }
    
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? deepSpace : Color.white
    }
    
    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? starWhite : Color(hex: "1A1A1F")
    }
    
    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? dustGray : Color(hex: "6A6A7A")
    }
}

// MARK: - Gradient Presets
extension Theme {
    static let spaceGradient = LinearGradient(
        colors: [spaceBlack.opacity(0.4), deepSpace.opacity(0.3)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    static let ringGradient = AngularGradient(
        colors: [stellarBlue, accentGlow, stellarBlue],
        center: .center
    )
    
    static let glowGradient = RadialGradient(
        colors: [accentGlow.opacity(0.3), .clear],
        center: .center,
        startRadius: 0,
        endRadius: 100
    )
    
    // Phase-specific ring gradients
    static func ringGradient(for phase: TimerPhase) -> AngularGradient {
        switch phase {
        case .focus:
            return AngularGradient(
                colors: [stellarBlue, accentGlow, stellarBlue],
                center: .center
            )
        case .break:
            return AngularGradient(
                colors: [Color(hex: "3A7A5A"), breakAccent, Color(hex: "3A7A5A")],
                center: .center
            )
        }
    }
}

// MARK: - Glass Modifiers
extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Theme.glassBorder, lineWidth: 0.5)
                    )
            )
    }
    
    func glassButton(isSelected: Bool = false, cornerRadius: CGFloat = 12) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(isSelected ? Theme.accentGlow.opacity(0.15) : Theme.glassBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(isSelected ? Theme.accentGlow.opacity(0.3) : Theme.glassBorder, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
