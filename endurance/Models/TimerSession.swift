//
//  TimerSession.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import Foundation
import SwiftData

@Model
final class TimerSession {
    var id: UUID
    var startTime: Date
    var endTime: Date?
    var duration: TimeInterval
    var actualDuration: TimeInterval?
    var completed: Bool
    var presetName: String
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        duration: TimeInterval,
        actualDuration: TimeInterval? = nil,
        completed: Bool = false,
        presetName: String = "Focus"
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.duration = duration
        self.actualDuration = actualDuration
        self.completed = completed
        self.presetName = presetName
    }
    
    func complete() {
        endTime = Date()
        completed = true
        if let endTime = endTime {
            actualDuration = endTime.timeIntervalSince(startTime)
        }
    }
    
    func cancel() {
        endTime = Date()
        completed = false
        if let endTime = endTime {
            actualDuration = endTime.timeIntervalSince(startTime)
        }
    }
}

// MARK: - Formatting Helpers
extension TimerSession {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        return "\(minutes) min"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
    
    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startTime)
    }
}
