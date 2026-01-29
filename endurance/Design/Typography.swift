//
//  Typography.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

enum Typography {
    // Timer display - large, bold, monospaced for consistent width
    static let timerDisplay = Font.system(size: 48, weight: .light, design: .rounded)
    static let timerDisplayMono = Font.system(size: 48, weight: .light, design: .monospaced)
    
    // Menu bar display - compact, readable
    static let menuBar = Font.system(size: 12, weight: .medium, design: .monospaced)
    
    // Headings
    static let heading = Font.system(size: 16, weight: .semibold, design: .rounded)
    static let subheading = Font.system(size: 13, weight: .medium, design: .rounded)
    
    // Body text
    static let body = Font.system(size: 13, weight: .regular, design: .rounded)
    static let caption = Font.system(size: 11, weight: .regular, design: .rounded)
    
    // Controls
    static let button = Font.system(size: 14, weight: .medium, design: .rounded)
    static let smallButton = Font.system(size: 12, weight: .medium, design: .rounded)
    
    // Stats/Analytics
    static let stat = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let statLabel = Font.system(size: 10, weight: .medium, design: .rounded)
}

// MARK: - Font Modifiers
extension View {
    func timerStyle() -> some View {
        self.font(Typography.timerDisplay)
            .monospacedDigit()
    }
    
    func menuBarStyle() -> some View {
        self.font(Typography.menuBar)
    }
    
    func headingStyle() -> some View {
        self.font(Typography.heading)
    }
    
    func captionStyle() -> some View {
        self.font(Typography.caption)
    }
}
