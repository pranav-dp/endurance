//
//  TimerPreset.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import Foundation
import SwiftUI

// MARK: - Preset Icons
enum PresetIcon: String, CaseIterable, Codable, Identifiable {
    case timer = "timer"
    case focus = "eye"
    case brain = "brain.head.profile"
    case bolt = "bolt.fill"
    case flame = "flame.fill"
    case moon = "moon.fill"
    case sun = "sun.max.fill"
    case star = "star.fill"
    case heart = "heart.fill"
    case leaf = "leaf.fill"
    case drop = "drop.fill"
    case mountain = "mountain.2.fill"
    
    var id: String { rawValue }
}

struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    var icon: PresetIcon
    let isDefault: Bool
    
    init(id: UUID = UUID(), name: String, duration: TimeInterval, icon: PresetIcon = .timer, isDefault: Bool = false) {
        self.id = id
        self.name = name
        self.duration = duration
        self.icon = icon
        self.isDefault = isDefault
    }
    
    // Human-readable duration
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return remainingMinutes > 0 ? "\(hours)h \(remainingMinutes)m" : "\(hours)h"
        }
        
        if seconds > 0 && minutes < 10 {
            return "\(minutes)m \(seconds)s"
        }
        
        return "\(minutes)m"
    }
    
    var shortDuration: String {
        let minutes = Int(duration) / 60
        return "\(minutes)"
    }
}

// MARK: - Default Presets
extension TimerPreset {
    static let pomodoro = TimerPreset(
        name: "Focus",
        duration: 25 * 60,
        icon: .focus,
        isDefault: true
    )
    
    static let shortBreak = TimerPreset(
        name: "Break",
        duration: 5 * 60,
        icon: .moon
    )
    
    static let longBreak = TimerPreset(
        name: "Rest",
        duration: 15 * 60,
        icon: .leaf
    )
    
    static let deepWork = TimerPreset(
        name: "Deep",
        duration: 50 * 60,
        icon: .brain
    )
    
    static let allDefaults: [TimerPreset] = [
        .pomodoro,
        .shortBreak,
        .longBreak,
        .deepWork
    ]
}

// MARK: - Preset Store for Custom Presets
@MainActor
@Observable
final class PresetStore {
    private let userDefaultsKey = "customPresets"
    
    var customPresets: [TimerPreset] = []
    
    init() {
        loadPresets()
    }
    
    var allPresets: [TimerPreset] {
        TimerPreset.allDefaults + customPresets
    }
    
    func addPreset(_ preset: TimerPreset) {
        customPresets.append(preset)
        savePresets()
    }
    
    func removePreset(_ preset: TimerPreset) {
        customPresets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func updatePreset(_ preset: TimerPreset) {
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
            savePresets()
        }
    }
    
    private func savePresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            customPresets = presets
        }
    }
}
