//
//  SidebarView.swift
//  endurance
//
//  Created by Pranav on 29/01/26.
//

import SwiftUI

// MARK: - Sidebar Navigation
enum SidebarTab: String, CaseIterable, Identifiable {
    case timer
    case presets
    case stats
    case settings
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .timer: return "stopwatch.fill"
        case .presets: return "slider.horizontal.3"
        case .stats: return "chart.bar.xaxis"
        case .settings: return "gearshape.fill"
        }
    }
}

// MARK: - Icon Strip Sidebar (Right side)
struct IconSidebar: View {
    @Binding var selectedTab: SidebarTab
    var onHideSidebar: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(SidebarTab.allCases) { tab in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                }) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(selectedTab == tab ? Theme.accentGlow : Theme.dustGray)
                        .frame(width: 36, height: 36)
                        .glassButton(isSelected: selectedTab == tab, cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            Spacer()
            
            // Hide sidebar button
            Button(action: onHideSidebar) {
                Image(systemName: "chevron.right.2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.dimGray)
                    .frame(width: 36, height: 36)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .frame(width: 52)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial.opacity(0.3))
        )
    }
}

// MARK: - Presets Panel
struct PresetsPanel: View {
    @Bindable var timerManager: TimerManager
    @Bindable var presetStore: PresetStore
    @Binding var showingAddPreset: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Text("Presets")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText(colorScheme))
                    
                    Spacer()
                    
                    Button(action: { showingAddPreset = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.accentGlow)
                            .frame(width: 28, height: 28)
                            .glassButton(cornerRadius: 8)
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Preset grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(presetStore.allPresets) { preset in
                        PresetCard(
                            preset: preset,
                            isSelected: timerManager.currentPreset.id == preset.id,
                            onTap: { 
                                timerManager.setPreset(preset)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                
                // Custom duration section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom Timer")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText(colorScheme))
                    
                    CustomDurationPicker(
                        duration: Binding(
                            get: { timerManager.customDuration },
                            set: { timerManager.setCustomDuration($0) }
                        ),
                        onApply: {
                            // Create a temporary custom preset
                            let customPreset = TimerPreset(
                                name: "Custom",
                                duration: timerManager.customDuration,
                                icon: .timer
                            )
                            timerManager.setPreset(customPreset)
                        }
                    )
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

// MARK: - Preset Card
struct PresetCard: View {
    let preset: TimerPreset
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Image(systemName: preset.icon.rawValue)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Theme.accentGlow : Theme.dustGray)
                
                Text(preset.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText(colorScheme))
                    .lineLimit(1)
                
                Text(preset.formattedDuration)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .glassButton(isSelected: isSelected, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Duration Picker (exact minutes, larger click targets)
struct CustomDurationPicker: View {
    @Binding var duration: TimeInterval
    var onApply: () -> Void
    
    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 10) {
            // Duration input
            HStack(spacing: 4) {
                TextField("", text: $textValue)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.primaryText(colorScheme))
                    .multilineTextAlignment(.center)
                    .frame(width: 50)
                    .focused($isFocused)
                    .onSubmit { applyValue() }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { applyValue() }
                    }
                
                Text("min")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassButton(cornerRadius: 10)
            
            // +/- buttons with LARGE click targets
            HStack(spacing: 6) {
                Button(action: { adjustDuration(by: -1) }) {
                    Image(systemName: "minus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.dustGray)
                        .frame(width: 40, height: 40)
                        .glassButton(cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                Button(action: { adjustDuration(by: 1) }) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.dustGray)
                        .frame(width: 40, height: 40)
                        .glassButton(cornerRadius: 10)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            Spacer()
            
            // Apply button
            Button(action: {
                applyValue()
                onApply()
            }) {
                Text("Set")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Theme.accentGlow)
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .onAppear {
            textValue = "\(Int(duration / 60))"
        }
        .onChange(of: duration) { _, newValue in
            textValue = "\(Int(newValue / 60))"
        }
    }
    
    private func applyValue() {
        if let minutes = Int(textValue), minutes > 0 {
            duration = TimeInterval(minutes * 60)
        } else {
            textValue = "\(Int(duration / 60))"
        }
    }
    
    private func adjustDuration(by minutes: Int) {
        let currentMinutes = Int(duration / 60)
        let newMinutes = max(1, currentMinutes + minutes)
        duration = TimeInterval(newMinutes * 60)
        textValue = "\(newMinutes)"
    }
}

// MARK: - Stats Panel (REAL data)
struct StatsPanel: View {
    @Bindable var sessionStore: SessionStore
    @State private var selectedPeriod: StatsPeriod = .week
    @State private var currentOffset: Int = 0
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Period selector (D W M Y)
            HStack(spacing: 4) {
                ForEach(StatsPeriod.allCases) { period in
                    Button(action: { 
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPeriod = period
                            currentOffset = 0
                        }
                    }) {
                        Text(period.shortLabel)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(selectedPeriod == period ? .white : Theme.dustGray)
                            .frame(width: 40, height: 30)
                            .background(
                                selectedPeriod == period
                                    ? Theme.accentGlow.opacity(0.9)
                                    : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
            }
            .padding(4)
            .glassButton(cornerRadius: 12)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Period navigation
            HStack {
                Button(action: { 
                    withAnimation { currentOffset -= 1 }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.dustGray)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(periodTitle)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primaryText(colorScheme))
                    
                    Text("\(sessionsInPeriod) sessions")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.accentGlow)
                }
                
                Spacer()
                
                Button(action: { 
                    if currentOffset < 0 {
                        withAnimation { currentOffset += 1 }
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(currentOffset >= 0 ? Theme.dimGray : Theme.dustGray)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(currentOffset >= 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            // Bar chart with REAL data
            chartView
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            
            // Summary stats
            HStack(spacing: 12) {
                StatBox(
                    value: formatTime(totalTimeInPeriod),
                    label: "Total"
                )
                StatBox(
                    value: "\(sessionsInPeriod)",
                    label: "Sessions"
                )
                StatBox(
                    value: formatTime(averageSessionTime),
                    label: "Average"
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Spacer()
        }
    }
    
    // MARK: - Chart View with REAL data
    @ViewBuilder
    private var chartView: some View {
        let data = realChartData
        let maxValue = data.map { $0.value }.max() ?? 1
        
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(data) { item in
                    VStack(spacing: 3) {
                        // Bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                item.value > 0
                                    ? LinearGradient(
                                        colors: [Theme.accentGlow, Theme.stellarBlue],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    : LinearGradient(
                                        colors: [Theme.dimGray.opacity(0.25), Theme.dimGray.opacity(0.15)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                            )
                            .frame(height: barHeight(value: item.value, maxVal: maxValue, totalHeight: geo.size.height - 18))
                        
                        // Label
                        if !item.label.isEmpty {
                            Text(item.label)
                                .font(.system(size: 8, weight: .medium, design: .rounded))
                                .foregroundStyle(Theme.dustGray)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(height: 100)
        .padding(12)
        .glassButton(cornerRadius: 14)
    }
    
    private func barHeight(value: Double, maxVal: Double, totalHeight: CGFloat) -> CGFloat {
        guard maxVal > 0 else { return 6 }
        return Swift.max(6, CGFloat(value / maxVal) * (totalHeight - 14))
    }
    
    // MARK: - Real Chart Data from SessionStore
    private var realChartData: [ChartItem] {
        let calendar = Calendar.current
        let baseDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: currentOffset, to: Date()) ?? Date()
        
        switch selectedPeriod {
        case .day:
            // 24 hours of the selected day
            let dayStart = calendar.startOfDay(for: baseDate)
            return (0..<24).map { hour in
                let hourStart = calendar.date(byAdding: .hour, value: hour, to: dayStart)!
                let hourEnd = calendar.date(byAdding: .hour, value: 1, to: hourStart)!
                let sessions = sessionsInRange(start: hourStart, end: hourEnd)
                let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration / 60 }
                return ChartItem(
                    label: hour % 4 == 0 ? "\(hour)" : "",
                    value: totalMinutes
                )
            }
            
        case .week:
            // 7 days
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)) ?? baseDate
            return (0..<7).map { day in
                let dayStart = calendar.date(byAdding: .day, value: day, to: weekStart)!
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let sessions = sessionsInRange(start: dayStart, end: dayEnd)
                let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration / 60 }
                let formatter = DateFormatter()
                formatter.dateFormat = "EEE"
                return ChartItem(
                    label: formatter.string(from: dayStart),
                    value: totalMinutes
                )
            }
            
        case .month:
            // Days of month
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) ?? baseDate
            let range = calendar.range(of: .day, in: .month, for: monthStart)!
            return range.map { day in
                let dayStart = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                let sessions = sessionsInRange(start: dayStart, end: dayEnd)
                let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration / 60 }
                return ChartItem(
                    label: day % 5 == 0 ? "\(day)" : "",
                    value: totalMinutes
                )
            }
            
        case .year:
            // 12 months
            let yearStart = calendar.date(from: calendar.dateComponents([.year], from: baseDate)) ?? baseDate
            let months = ["J", "F", "M", "A", "M", "J", "J", "A", "S", "O", "N", "D"]
            return (0..<12).map { month in
                let monthStart = calendar.date(byAdding: .month, value: month, to: yearStart)!
                let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)!
                let sessions = sessionsInRange(start: monthStart, end: monthEnd)
                let totalMinutes = sessions.reduce(0.0) { $0 + $1.duration / 60 }
                return ChartItem(
                    label: months[month],
                    value: totalMinutes
                )
            }
        }
    }
    
    private func sessionsInRange(start: Date, end: Date) -> [TimerSession] {
        sessionStore.fetchRecentSessions(limit: 1000).filter { session in
            session.startTime >= start && session.startTime < end && session.completed
        }
    }
    
    private var sessionsInPeriod: Int {
        realChartData.filter { $0.value > 0 }.count > 0 
            ? sessionsInRange(start: periodStart, end: periodEnd).count 
            : 0
    }
    
    private var totalTimeInPeriod: TimeInterval {
        sessionsInRange(start: periodStart, end: periodEnd).reduce(0) { $0 + $1.duration }
    }
    
    private var averageSessionTime: TimeInterval {
        let sessions = sessionsInRange(start: periodStart, end: periodEnd)
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.duration } / Double(sessions.count)
    }
    
    private var periodStart: Date {
        let calendar = Calendar.current
        let baseDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: currentOffset, to: Date()) ?? Date()
        
        switch selectedPeriod {
        case .day:
            return calendar.startOfDay(for: baseDate)
        case .week:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)) ?? baseDate
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: baseDate)) ?? baseDate
        case .year:
            return calendar.date(from: calendar.dateComponents([.year], from: baseDate)) ?? baseDate
        }
    }
    
    private var periodEnd: Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: selectedPeriod.calendarComponent, value: 1, to: periodStart) ?? periodStart
    }
    
    private var periodTitle: String {
        let calendar = Calendar.current
        let baseDate = calendar.date(byAdding: selectedPeriod.calendarComponent, value: currentOffset, to: Date()) ?? Date()
        
        switch selectedPeriod {
        case .day:
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: baseDate)
        case .week:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: baseDate)) ?? baseDate
            return "Week of \(formatter.string(from: weekStart))"
        case .month:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: baseDate)
        case .year:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy"
            return formatter.string(from: baseDate)
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Stat Box
struct StatBox: View {
    let value: String
    let label: String
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.primaryText(colorScheme))
            
            Text(label)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.secondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassButton(cornerRadius: 10)
    }
}

// MARK: - Stats Period
enum StatsPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    
    var id: String { rawValue }
    
    var shortLabel: String {
        switch self {
        case .day: return "D"
        case .week: return "W"
        case .month: return "M"
        case .year: return "Y"
        }
    }
    
    var calendarComponent: Calendar.Component {
        switch self {
        case .day: return .day
        case .week: return .weekOfYear
        case .month: return .month
        case .year: return .year
        }
    }
}

// MARK: - Chart Item
struct ChartItem: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
}

// MARK: - Add Preset Sheet
struct AddPresetSheet: View {
    @Bindable var presetStore: PresetStore
    @Binding var isPresented: Bool
    
    @State private var name: String = ""
    @State private var minutes: Int = 25
    @State private var selectedIcon: PresetIcon = .timer
    
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("New Preset")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.primaryText(colorScheme))
                
                Spacer()
                
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.dustGray)
                        .frame(width: 24, height: 24)
                        .background(Theme.glassBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
            }
            
            // Name field
            VStack(alignment: .leading, spacing: 4) {
                Text("Name")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
                
                TextField("Preset name", text: $name)
                    .font(.system(size: 13, design: .rounded))
                    .textFieldStyle(.plain)
                    .padding(10)
                    .glassButton(cornerRadius: 8)
            }
            
            // Duration
            VStack(alignment: .leading, spacing: 4) {
                Text("Duration")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
                
                HStack {
                    TextField("", value: $minutes, format: .number)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .multilineTextAlignment(.center)
                        .frame(width: 50)
                        .textFieldStyle(.plain)
                    
                    Text("minutes")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.secondaryText(colorScheme))
                }
                .padding(10)
                .glassButton(cornerRadius: 8)
            }
            
            // Icon selection
            VStack(alignment: .leading, spacing: 4) {
                Text("Icon")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText(colorScheme))
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                    ForEach(PresetIcon.allCases) { icon in
                        Button(action: { selectedIcon = icon }) {
                            Image(systemName: icon.rawValue)
                                .font(.system(size: 16))
                                .foregroundStyle(selectedIcon == icon ? Theme.accentGlow : Theme.dustGray)
                                .frame(width: 32, height: 32)
                                .glassButton(isSelected: selectedIcon == icon, cornerRadius: 8)
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                    }
                }
            }
            
            Spacer()
            
            // Save button
            Button(action: savePreset) {
                Text("Save Preset")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [Theme.stellarBlue, Theme.accentGlow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(name.isEmpty)
            .opacity(name.isEmpty ? 0.5 : 1)
        }
        .padding(16)
        .frame(width: 260, height: 360)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
    
    private func savePreset() {
        let preset = TimerPreset(
            name: name,
            duration: TimeInterval(minutes * 60),
            icon: selectedIcon
        )
        presetStore.addPreset(preset)
        isPresented = false
    }
}
