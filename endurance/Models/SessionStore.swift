//
//  SessionStore.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import Foundation
import SwiftData

enum TimePeriod: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var dateRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date()
        
        switch self {
        case .day:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
            
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
            
        case .year:
            let start = calendar.date(from: calendar.dateComponents([.year], from: now))!
            let end = calendar.date(byAdding: .year, value: 1, to: start)!
            return (start, end)
        }
    }
}

struct DailyStats: Identifiable {
    let id = UUID()
    let date: Date
    let totalFocusTime: TimeInterval
    let sessionsCompleted: Int
    
    var formattedTime: String {
        let hours = Int(totalFocusTime) / 3600
        let minutes = (Int(totalFocusTime) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
    
    var dayLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
}

@MainActor
@Observable
final class SessionStore {
    private var modelContext: ModelContext?
    
    var todayStats: DailyStats?
    var weekStats: [DailyStats] = []
    var totalFocusTime: TimeInterval = 0
    var totalSessions: Int = 0
    var completionRate: Double = 0
    
    // Daily Goal (persisted)
    var dailyGoalMinutes: Int {
        get { 
            let val = UserDefaults.standard.integer(forKey: "dailyGoalMinutes")
            return val > 0 ? val : 120  // Default 2 hours
        }
        set { 
            UserDefaults.standard.set(newValue, forKey: "dailyGoalMinutes")
        }
    }
    
    var dailyProgress: Double {
        guard dailyGoalMinutes > 0 else { return 0 }
        let todayMinutes = (todayStats?.totalFocusTime ?? 0) / 60
        return min(1.0, todayMinutes / Double(dailyGoalMinutes))
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
        refreshStats()
    }
    
    // MARK: - Session Management
    func createSession(duration: TimeInterval, presetName: String) -> TimerSession {
        let session = TimerSession(duration: duration, presetName: presetName)
        modelContext?.insert(session)
        try? modelContext?.save()
        return session
    }
    
    func completeSession(_ session: TimerSession) {
        session.complete()
        try? modelContext?.save()
        refreshStats()
    }
    
    func cancelSession(_ session: TimerSession) {
        session.cancel()
        try? modelContext?.save()
        refreshStats()
    }
    
    func deleteSession(_ session: TimerSession) {
        modelContext?.delete(session)
        try? modelContext?.save()
        refreshStats()
    }
    
    // MARK: - Queries
    func fetchSessions(for period: TimePeriod) -> [TimerSession] {
        guard let context = modelContext else { return [] }
        
        let range = period.dateRange
        let startDate = range.start
        let endDate = range.end
        
        let descriptor = FetchDescriptor<TimerSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        guard let allSessions = try? context.fetch(descriptor) else { return [] }
        
        return allSessions.filter { session in
            session.startTime >= startDate && session.startTime < endDate
        }
    }
    
    func fetchRecentSessions(limit: Int = 10) -> [TimerSession] {
        guard let context = modelContext else { return [] }
        
        var descriptor = FetchDescriptor<TimerSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        return (try? context.fetch(descriptor)) ?? []
    }
    
    // MARK: - Statistics
    func refreshStats() {
        guard let context = modelContext else { return }
        
        // Fetch all sessions
        let descriptor = FetchDescriptor<TimerSession>(
            sortBy: [SortDescriptor(\.startTime, order: .reverse)]
        )
        
        guard let allSessions = try? context.fetch(descriptor) else { return }
        
        // Today's stats
        let todayRange = TimePeriod.day.dateRange
        let todaySessions = allSessions.filter { session in
            session.startTime >= todayRange.start &&
            session.startTime < todayRange.end &&
            session.completed
        }
        
        let totalTime = todaySessions.reduce(0) { $0 + $1.duration }
        todayStats = DailyStats(
            date: Date(),
            totalFocusTime: totalTime,
            sessionsCompleted: todaySessions.count
        )
        
        // Week stats
        calculateWeekStats(from: allSessions)
        
        // All-time stats
        totalSessions = allSessions.count
        totalFocusTime = allSessions.filter { $0.completed }.reduce(0) { $0 + $1.duration }
        
        let completed = allSessions.filter { $0.completed }.count
        completionRate = totalSessions > 0 ? Double(completed) / Double(totalSessions) : 0
    }
    
    private func calculateWeekStats(from allSessions: [TimerSession]) {
        let calendar = Calendar.current
        let today = Date()
        var stats: [DailyStats] = []
        
        for dayOffset in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -dayOffset, to: calendar.startOfDay(for: today)),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            
            let daySessions = allSessions.filter { session in
                session.startTime >= dayStart &&
                session.startTime < dayEnd &&
                session.completed
            }
            
            let totalTime = daySessions.reduce(0) { $0 + $1.duration }
            stats.append(DailyStats(
                date: dayStart,
                totalFocusTime: totalTime,
                sessionsCompleted: daySessions.count
            ))
        }
        
        weekStats = stats
    }
}
