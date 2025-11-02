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
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("Your Streak")
                        .font(.largeTitle.bold())
                        .foregroundColor(.appTextPrimary)
                        .padding(.top, 20)
                    
                    // Month/Year
                    Text(monthYearString(from: currentMonth))
                        .font(.title3)
                        .foregroundColor(.appTextSecondary)
                    
                    // Calendar
                    calendarView
                        .padding(.horizontal)
                    
                    // Streak Stats
                    streakStatsView
                        .padding(.horizontal)
                    
                    if isLoading {
                        ProgressView()
                            .tint(.appAccent)
                            .padding()
                    }
                }
                .padding(.bottom, 100)
            }
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
    }
    
    // MARK: - Calendar View - ADAPTIVE
    
    private var calendarView: some View {
        VStack(spacing: 20) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.appTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 16) {
                ForEach(calendarDays, id: \.self) { date in
                    dayCell(for: date)
                }
            }
        }
        .padding()
        .background(Color.appCardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .cornerRadius(20)
    }
    
    private func dayCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let dayNumber = Calendar.current.component(.day, from: date)
                let isCompleted = completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
                let isToday = Calendar.current.isDateInToday(date)
                
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(isToday ? Color.appAccent : Color.appCardBorder, lineWidth: 2)
                            .frame(width: 40, height: 40)
                        
                        if isCompleted {
                            Circle()
                                .fill(Color.appAccent.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }
                        
                        Text("\(dayNumber)")
                            .font(.system(size: 16, weight: isToday ? .bold : .regular))
                            .foregroundColor(.appTextPrimary)
                    }
                    
                    // Lightning icon for completed days
                    if isCompleted {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.appAccent)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                }
            } else {
                Color.clear.frame(width: 40, height: 56)
            }
        }
    }
    
    // MARK: - Streak Stats - ADAPTIVE
    
    private var streakStatsView: some View {
        HStack(spacing: 20) {
            // Current Streak
            VStack(spacing: 8) {
                Text("\(meterDataManager.meterData?.streak ?? 0)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.appAccent)
                
                Text("Current Streak")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
            
            // Longest Streak
            VStack(spacing: 8) {
                Text("\(meterDataManager.meterData?.streak ?? 0)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Longest Streak")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.appCardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
            .cornerRadius(16)
        }
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
