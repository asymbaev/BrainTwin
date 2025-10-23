import SwiftUI

struct InsightsView: View {
    @StateObject private var viewModel = InsightsViewModel()
    @State private var currentMonth = Date()
    
    var body: some View {
        ZStack {
            // Same gradient as Dashboard
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.1, blue: 0.35),
                    Color(red: 0.08, green: 0.05, blue: 0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    Text("Your Streak")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                        .padding(.top, 20)
                    
                    // Month/Year
                    Text(monthYearString(from: currentMonth))
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                    
                    // Calendar
                    calendarView
                        .padding(.horizontal)
                    
                    // Streak Stats
                    streakStatsView
                        .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                            .padding()
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadStreakData()
        }
        .refreshable {
            await viewModel.loadStreakData()
        }
    }
    
    // MARK: - Calendar View
    
    private var calendarView: some View {
        VStack(spacing: 20) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
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
        .background(Color.white.opacity(0.05))
        .cornerRadius(20)
    }
    
    private func dayCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let dayNumber = Calendar.current.component(.day, from: date)
                let isCompleted = viewModel.completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
                let isToday = Calendar.current.isDateInToday(date)
                
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .stroke(isToday ? Color.yellow : Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 40, height: 40)
                        
                        if isCompleted {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 40, height: 40)
                        }
                        
                        Text("\(dayNumber)")
                            .font(.system(size: 16, weight: isToday ? .bold : .regular))
                            .foregroundColor(.white)
                    }
                    
                    // Lightning icon for completed days
                    if isCompleted {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.yellow)
                    } else {
                        Color.clear.frame(height: 16)
                    }
                }
            } else {
                Color.clear.frame(width: 40, height: 56)
            }
        }
    }
    
    // MARK: - Streak Stats
    
    private var streakStatsView: some View {
        HStack(spacing: 20) {
            // Current Streak
            VStack(spacing: 8) {
                Text("\(viewModel.currentStreak)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.yellow)
                
                Text("Current Streak")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            // Longest Streak
            VStack(spacing: 8) {
                Text("\(viewModel.longestStreak)")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(.green)
                
                Text("Longest Streak")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
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
}
