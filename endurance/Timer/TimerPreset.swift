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
    case focus = "target"
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
    case book = "book.fill"
    case graduationcap = "graduationcap.fill"
    
    var id: String { rawValue }
}

// MARK: - Timer Preset
struct TimerPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var icon: PresetIcon
    var isDefault: Bool
    
    // Session configuration
    var focusDuration: TimeInterval      // Duration of each focus session
    var breakDuration: TimeInterval      // Break duration between focus sessions
    var numberOfSessions: Int            // How many focus sessions in total
    
    init(
        id: UUID = UUID(),
        name: String,
        icon: PresetIcon = .timer,
        isDefault: Bool = false,
        focusDuration: TimeInterval = 25 * 60,
        breakDuration: TimeInterval = 5 * 60,
        numberOfSessions: Int = 4
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.isDefault = isDefault
        self.focusDuration = focusDuration
        self.breakDuration = breakDuration
        self.numberOfSessions = numberOfSessions
    }
    
    // MARK: - Computed Properties
    
    /// Total focus time: sessions × focusDuration
    var totalFocusTime: TimeInterval {
        focusDuration * Double(numberOfSessions)
    }
    
    /// Total break time: (sessions − 1) × breakDuration
    var totalBreakTime: TimeInterval {
        breakDuration * Double(max(0, numberOfSessions - 1))
    }
    
    /// Total session duration: focus + breaks
    var totalDuration: TimeInterval {
        totalFocusTime + totalBreakTime
    }
    
    /// Human-readable focus duration (e.g., "25m", "1h 30m")
    var formattedFocusDuration: String {
        formatDuration(focusDuration)
    }
    
    /// Human-readable break duration
    var formattedBreakDuration: String {
        formatDuration(breakDuration)
    }
    
    /// Human-readable total duration
    var formattedTotalDuration: String {
        formatDuration(totalDuration)
    }
    
    /// Summary like "25m focus • 4 sessions"
    var summaryDescription: String {
        "\(formattedFocusDuration) focus • \(numberOfSessions) sessions"
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        
        return "\(totalMinutes)m"
    }
}

// MARK: - Default Presets
extension TimerPreset {
    /// Stable UUIDs for default presets
    private static let classicPomodoroID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private static let deepWorkID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    private static let studySprintID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    private static let marathonID = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    
    /// Classic Pomodoro: 25m focus, 5m break, 4 sessions
    static let classicPomodoro = TimerPreset(
        id: classicPomodoroID,
        name: "Classic",
        icon: .focus,
        isDefault: true,
        focusDuration: 25 * 60,
        breakDuration: 5 * 60,
        numberOfSessions: 4
    )
    
    /// Deep Work: 50m focus, 10m break, 4 sessions
    static let deepWork = TimerPreset(
        id: deepWorkID,
        name: "Deep Work",
        icon: .brain,
        isDefault: true,
        focusDuration: 50 * 60,
        breakDuration: 10 * 60,
        numberOfSessions: 4
    )
    
    /// Study Sprint: 45m focus, 15m break, 3 sessions
    static let studySprint = TimerPreset(
        id: studySprintID,
        name: "Study Sprint",
        icon: .graduationcap,
        isDefault: true,
        focusDuration: 45 * 60,
        breakDuration: 15 * 60,
        numberOfSessions: 3
    )
    
    /// Marathon: 90m focus, 20m break, 3 sessions
    static let marathon = TimerPreset(
        id: marathonID,
        name: "Marathon",
        icon: .flame,
        isDefault: true,
        focusDuration: 90 * 60,
        breakDuration: 20 * 60,
        numberOfSessions: 3
    )
    
    static let allDefaults: [TimerPreset] = [
        .classicPomodoro,
        .deepWork,
        .studySprint,
        .marathon
    ]
}

// MARK: - Preset Store
@MainActor
@Observable
final class PresetStore {
    // Bumped version to force fresh load after removing long break fields
    private let userDefaultsKey = "pomodoroPresets_v3"
    private let defaultPresetsKey = "defaultPresetsCustomized_v3"
    
    var customPresets: [TimerPreset] = []
    var defaultPresets: [TimerPreset] = TimerPreset.allDefaults
    
    init() {
        loadPresets()
    }
    
    var allPresets: [TimerPreset] {
        defaultPresets + customPresets
    }
    
    // MARK: - Preset Management
    
    func addPreset(_ preset: TimerPreset) {
        customPresets.append(preset)
        savePresets()
    }
    
    func removePreset(_ preset: TimerPreset) {
        customPresets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func updatePreset(_ preset: TimerPreset) {
        if let index = defaultPresets.firstIndex(where: { $0.id == preset.id }) {
            defaultPresets[index] = preset
            savePresets()
            return
        }
        
        if let index = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[index] = preset
            savePresets()
        }
    }
    
    func resetDefaultPreset(_ preset: TimerPreset) {
        if let original = TimerPreset.allDefaults.first(where: { $0.id == preset.id }),
           let index = defaultPresets.firstIndex(where: { $0.id == preset.id }) {
            defaultPresets[index] = original
            savePresets()
        }
    }
    
    // MARK: - Persistence
    
    private func savePresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        
        if let data = try? JSONEncoder().encode(defaultPresets) {
            UserDefaults.standard.set(data, forKey: defaultPresetsKey)
        }
    }
    
    private func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: defaultPresetsKey),
           let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            defaultPresets = presets
        }
        
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let presets = try? JSONDecoder().decode([TimerPreset].self, from: data) {
            customPresets = presets
        }
    }
}
