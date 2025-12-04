import SwiftUI
import Supabase

struct InsightsView: View {
    @EnvironmentObject var meterDataManager: MeterDataManager
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as DailyHackView)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var completedDates: [Date] = []
    @State private var isLoading = false
    @State private var currentMonth = Date()
    @State private var flamePulse: Bool = false
    @State private var isStreakExpanded: Bool = false
    
    // Initialize supabase properly
    private var supabase: SupabaseManager {
        SupabaseManager.shared
    }
    
    // ✅ Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }
    
    var body: some View {
        ZStack {
            // ✅ Adaptive background (same as DailyHackView pages 2-3)
            Color.appBackground.ignoresSafeArea()
            
            // ✅ Subtle depth gradient (only in dark mode)
            if colorScheme == .dark {
                RadialGradient(
                    colors: [
                        Color(white: 0.04),
                        Color.black
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 0) {
                // Dynamic Island-style streak counter
                dynamicIslandStreakCounter
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isStreakExpanded.toggle()
                        }
                    }
                
                Spacer(minLength: 20)
                
                // Floating calendar with particles
                floatingCalendarWithParticles
                    .padding(.horizontal, 20)
                
                Spacer(minLength: 20)
                
                // Integrated stats indicators
                integratedStatsIndicators
                    .padding(.horizontal, 20)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .tint(.appAccent)
                        .padding()
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // ✅ Apply user's preferred color scheme
        .preferredColorScheme(preferredColorScheme)
        .task {
            // Only fetch completed dates for calendar
            // Streak data comes from preloaded meter data!
            await loadCompletedDates()
            
            // Fetch meter data if not already loaded
            if meterDataManager.meterData == nil {
                print("⚠️ Meter data not preloaded, fetching now...")
                await meterDataManager.fetchMeterData()
            } else {
                print("✅ Using preloaded meter data for streaks!")
            }
        }
        .refreshable {
            await meterDataManager.fetchMeterData(force: true)
            await loadCompletedDates()
        }
        .onAppear {
            // Start flame pulsing animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                flamePulse = true
            }
        }
    }
    
    // MARK: - Viral 2025 Design Components
    
    // Dynamic Island-style Streak Counter
    private var dynamicIslandStreakCounter: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: isStreakExpanded ? 24 : 40)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.9),
                            Color(red: 0.1, green: 0.1, blue: 0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: Color.appAccent.opacity(0.3), radius: isStreakExpanded ? 20 : 10)
            
            // Content
            if isStreakExpanded {
                // Expanded state
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("🔥")
                            .font(.system(size: 40))
                            .scaleEffect(flamePulse ? 1.1 : 0.9)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.system(size: 36, weight: .black))
                                .foregroundColor(.white)
                            
                            Text("Day Streak")
                                .font(.subheadline.bold())
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                    }
                    
                    // Motivational message
                    Text(motivationalMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            } else {
                // Collapsed state
                HStack(spacing: 10) {
                    Text("🔥")
                        .font(.system(size: 24))
                        .scaleEffect(flamePulse ? 1.05 : 0.95)
                    
                    Text("\(currentStreak)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .frame(height: isStreakExpanded ? 120 : 48)
        .frame(maxWidth: isStreakExpanded ? .infinity : 120)
    }
    
    // Floating Calendar with Particles
    private var floatingCalendarWithParticles: some View {
        VStack(spacing: 20) {
            // Month/Year header
            Text(monthYearString(from: currentMonth))
                .font(.title2.bold())
                .foregroundColor(.appTextPrimary)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid with particle effects
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 12) {
                ForEach(calendarDays, id: \.self) { date in
                    particleDayCell(for: date)
                }
            }
        }
        .padding(24)
        .background(
            ZStack {
                // Glassmorphism background
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.appCardBackground.opacity(0.8))
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial)
                    )
                
                // Subtle gradient overlay
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.appAccent.opacity(0.05),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.appAccent.opacity(0.3),
                            Color.appCardBorder
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
    
    // Particle Day Cell with glow effects
    private func particleDayCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let dayNumber = Calendar.current.component(.day, from: date)
                let isCompleted = completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
                let isToday = Calendar.current.isDateInToday(date)
                
                ZStack {
                    // Particle glow for completed days
                    if isCompleted {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [
                                        Color.appAccent.opacity(0.4),
                                        Color.appAccent.opacity(0.1),
                                        Color.clear
                                    ],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 25
                                )
                            )
                            .frame(width: 50, height: 50)
                            .blur(radius: 8)
                    }
                    
                    // Today's gradient ring
                    if isToday {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange, Color.appAccent],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 44, height: 44)
                    }
                    
                    // Completed day background
                    if isCompleted {
                        Circle()
                            .fill(Color.appAccent.opacity(0.2))
                            .frame(width: 44, height: 44)
                    }
                    
                    // Content
                    if isCompleted {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.appAccent.opacity(0.5), radius: 4)
                    } else {
                        Text("\(dayNumber)")
                            .font(.system(size: 16, weight: isToday ? .bold : .regular))
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .frame(width: 44, height: 44)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
        }
    }
    
    // Integrated Stats Indicators (glowing)
    private var integratedStatsIndicators: some View {
        HStack(spacing: 16) {
            // Current Streak
            glowingStatIndicator(
                label: "Current",
                value: "\(meterDataManager.meterData?.streak ?? 0)",
                color: Color.appAccent
            )
            
            // Longest Streak
            glowingStatIndicator(
                label: "Longest",
                value: "\(meterDataManager.meterData?.streak ?? 0)",
                color: Color.green
            )
        }
    }
    
    private func glowingStatIndicator(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            // Glowing number
            ZStack {
                // Glow effect
                Text(value)
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(color)
                    .blur(radius: 10)
                    .opacity(0.6)
                
                // Actual number
                Text(value)
                    .font(.system(size: 36, weight: .black))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color, color.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.appTextSecondary)
                .textCase(.uppercase)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.ultraThinMaterial)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: color.opacity(0.2), radius: 10, x: 0, y: 5)
    }
    
    // Motivational message based on streak
    private var motivationalMessage: String {
        switch currentStreak {
        case 0:
            return "Start your journey today!"
        case 1:
            return "Great start! Keep going"
        case 2...6:
            return "Building momentum 🚀"
        case 7...13:
            return "You're on fire! 🔥"
        case 14...29:
            return "Unstoppable force!"
        default:
            return "Legendary status achieved! 👑"
        }
    }
    
    // MARK: - Helper Properties
    
    private var currentStreak: Int {
        meterDataManager.meterData?.streak ?? 0
    }
    
    // Gradient colors for streak number
    private var streakGradientColors: [Color] {
        switch currentStreak {
        case 0...6:
            return [Color.orange, Color.yellow]
        case 7...13:
            return [Color.orange, Color.red]
        case 14...29:
            return [Color(red: 1.0, green: 0.5, blue: 0.0), Color.red]
        default:
            return [Color.red, Color.pink]
        }
    }
    
    // MARK: - Compact Calendar View
    
    private var compactCalendarView: some View {
        VStack(spacing: 12) {
            // Month/Year header
            Text(monthYearString(from: currentMonth))
                .font(.headline)
                .foregroundColor(.appTextPrimary)
            
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2.bold())
                        .foregroundColor(.appTextTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid - more compact
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(calendarDays, id: \.self) { date in
                    compactDayCell(for: date)
                }
            }
        }
        .padding(16)
        .background(Color.appCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .cornerRadius(16)
    }
    
    private func compactDayCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let dayNumber = Calendar.current.component(.day, from: date)
                let isCompleted = completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
                let isToday = Calendar.current.isDateInToday(date)
                
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.appAccent.opacity(0.2) : Color.clear)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(isToday ? Color.appAccent : (isCompleted ? Color.appAccent.opacity(0.5) : Color.clear), lineWidth: 1.5)
                        )
                    
                    if isCompleted {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.appAccent)
                    } else {
                        Text("\(dayNumber)")
                            .font(.system(size: 12, weight: isToday ? .bold : .regular))
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .frame(width: 32, height: 32)
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
    }
    
    // MARK: - Streak Stats - Gradient Cards
    
    private var streakStatsView: some View {
        HStack(spacing: 12) {
            // Current Streak - Orange gradient
            gradientStatCard(
                value: "\(meterDataManager.meterData?.streak ?? 0)",
                label: "Current Streak",
                gradientColors: [
                    Color(red: 1.0, green: 0.6, blue: 0.2),
                    Color(red: 1.0, green: 0.8, blue: 0.3)
                ]
            )
            
            // Longest Streak - Green gradient
            gradientStatCard(
                value: "\(meterDataManager.meterData?.streak ?? 0)",
                label: "Longest Streak",
                gradientColors: [
                    Color(red: 0.2, green: 0.8, blue: 0.4),
                    Color(red: 0.4, green: 0.9, blue: 0.6)
                ]
            )
        }
    }
    
    private func gradientStatCard(value: String, label: String, gradientColors: [Color]) -> some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glassmorphism overlay
            Color.white.opacity(0.15)
            
            // Content
            VStack(spacing: 6) {
                Text(value)
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
    
    // MARK: - Load Completed Dates (for calendar only)
    
    private func loadCompletedDates() async {
        guard let userId = supabase.userId else {
            print("❌ No user ID found")
            return
        }
        
        isLoading = true
        
        do {
            // Fetch completed dates for this month
            let calendar = Calendar.current
            let now = Date()
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            let startDateString = formatter.string(from: startOfMonth)
            let endDateString = formatter.string(from: endOfMonth)
            
            struct CompletedTask: Decodable {
                let date: String
                let completed_at: String?
            }
            
            let tasks: [CompletedTask] = try await supabase.client
                .from("daily_tasks")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            // Convert to Date objects
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)  // ✅ Use UTC to match backend dates
            
            completedDates = tasks.compactMap { task in
                dateFormatter.date(from: task.date)
            }
            
            print("✅ Loaded \(completedDates.count) completed days this month")
            
        } catch {
            print("❌ Load completed dates error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - Helpers
    
    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count ?? 0
        
        var days: [Date?] = []
        
        // Add empty cells before first day
        for _ in 1..<firstWeekday {
            days.append(nil)
        }
        
        // Add actual days
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDayOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}

#Preview {
    InsightsView()
        .environmentObject(MeterDataManager.shared)
}
