import SwiftUI
import Supabase
import os

struct InsightsView: View {
    @EnvironmentObject var meterDataManager: MeterDataManager
    @Environment(\.colorScheme) var colorScheme

    @AppStorage("appearanceMode") private var appearanceMode = "system"

    @State private var completedDates: [Date] = []
    @State private var allCompletedDates: [Date] = []  // All dates for longest streak calculation
    @State private var isLoading = false
    @State private var currentMonth = Date()
    @State private var showAchievements = false
    @State private var animateProgress = false
    @State private var animateStats = false

    private var supabase: SupabaseManager {
        SupabaseManager.shared
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ZStack {
                Color.appBackground.ignoresSafeArea()

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

                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)
                        .padding(.top, 10)

                    // Hero Stats Ring
                    heroStatsCard
                        .padding(.horizontal, 20)

                    // Bento Grid Layout
                    bentoGridLayout
                        .padding(.horizontal, 20)

                    // Achievement Gallery
                    achievementGallery
                        .padding(.leading, 20)

                    // Premium Heatmap Calendar
                    premiumHeatmapCalendar
                        .padding(.horizontal, 20)

                    // Progress Categories
                    progressCategories
                        .padding(.horizontal, 20)

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(preferredColorScheme)
        .task {
            await loadCompletedDates()
            if meterDataManager.meterData == nil {
                await meterDataManager.fetchMeterData()
            }

            // Animate on appear
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                animateProgress = true
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.4)) {
                animateStats = true
            }
        }
        .refreshable {
            await meterDataManager.fetchMeterData(force: true)
            await loadCompletedDates()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Progress")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.appTextPrimary)

                Text("Your journey to excellence")
                    .font(.subheadline)
                    .foregroundColor(.appTextSecondary)
            }

            Spacer()

            // Share button
            Button(action: {}) {
                ZStack {
                    Circle()
                        .fill(Color.appCardBackground)
                        .frame(width: 44, height: 44)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)

                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
        }
    }

    // MARK: - Hero Stats Card

    private var heroStatsCard: some View {
        ZStack {
            // Background with gradient
            RoundedRectangle(cornerRadius: 32)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.appAccent.opacity(0.15),
                            Color.orange.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 32)
                        .fill(.ultraThinMaterial)
                )

            VStack(spacing: 20) {
                // Large circular progress ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(
                            Color.appProgressTrack.opacity(0.3),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)

                    // Progress ring with gradient
                    Circle()
                        .trim(from: 0, to: animateProgress ? progressPercentage : 0)
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.appAccent,
                                    Color.orange,
                                    Color.appAccent.opacity(0.8),
                                    Color.appAccent
                                ],
                                center: .center,
                                startAngle: .degrees(0),
                                endAngle: .degrees(360)
                            ),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .frame(width: 180, height: 180)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: Color.appAccent.opacity(0.4), radius: 12, x: 0, y: 6)

                    // Center content
                    VStack(spacing: 4) {
                        Text("\(Int(progressPercentage * 100))")
                            .font(.system(size: 56, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .scaleEffect(animateProgress ? 1.0 : 0.8)

                        Text("Power Score")
                            .font(.caption.bold())
                            .foregroundColor(.appTextSecondary)
                            .textCase(.uppercase)
                            .tracking(1.2)
                    }

                    // Floating particles
                    if animateProgress {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.appAccent.opacity(0.6))
                                .frame(width: 8, height: 8)
                                .offset(x: particleOffset(for: index).x, y: particleOffset(for: index).y)
                                .blur(radius: 2)
                        }
                    }
                }

                // Quick stats row
                HStack(spacing: 20) {
                    miniStatPill(icon: "flame.fill", value: "\(currentStreak)", label: "Day Streak", color: .appAccent)
                    miniStatPill(icon: "chart.line.uptrend.xyaxis", value: "+\(growthRate)%", label: "Growth", color: .green)
                    miniStatPill(icon: "trophy.fill", value: "\(totalAchievements)", label: "Wins", color: .purple)
                }
                .opacity(animateStats ? 1.0 : 0.0)
                .offset(y: animateStats ? 0 : 20)
            }
            .padding(32)
        }
        .frame(height: 340)
    }

    private func miniStatPill(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.appTextPrimary)

            Text(label)
                .font(.caption2)
                .foregroundColor(.appTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.appCardBackground.opacity(0.8))
                .shadow(color: color.opacity(0.15), radius: 8, x: 0, y: 4)
        )
    }

    // MARK: - Bento Grid Layout

    private var bentoGridLayout: some View {
        VStack(spacing: 16) {
            // Row 1: Two medium cards
            HStack(spacing: 16) {
                // Current Streak Card
                bentoCard(
                    title: "Current Streak",
                    value: "\(currentStreak)",
                    subtitle: "days in a row",
                    icon: "flame.fill",
                    gradientColors: [Color.appAccent, Color.orange],
                    size: .medium
                )

                // Personal Best Card
                bentoCard(
                    title: "Personal Best",
                    value: "\(longestStreak)",
                    subtitle: "longest streak",
                    icon: "crown.fill",
                    gradientColors: [Color.purple, Color.pink],
                    size: .medium
                )
            }

            // Row 2: Three small cards
            HStack(spacing: 16) {
                bentoCard(
                    title: "Total",
                    value: "\(totalDays)",
                    subtitle: "days",
                    icon: "calendar",
                    gradientColors: [Color.blue, Color.cyan],
                    size: .small
                )

                bentoCard(
                    title: "Level",
                    value: "\(currentLevel)",
                    subtitle: "tier",
                    icon: "star.fill",
                    gradientColors: [Color.appAccent, Color.yellow],
                    size: .small
                )

                bentoCard(
                    title: "Rank",
                    value: "Top \(userRank)%",
                    subtitle: "global",
                    icon: "chart.bar.fill",
                    gradientColors: [Color.green, Color.mint],
                    size: .small
                )
            }
        }
    }

    private func bentoCard(title: String, value: String, subtitle: String, icon: String, gradientColors: [Color], size: CardSize) -> some View {
        VStack(alignment: .leading, spacing: size == .small ? 8 : 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: size == .small ? 16 : 20, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Spacer()

                if size == .medium {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundColor(.appTextSecondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }

            if size == .small {
                Text(title)
                    .font(.caption2.bold())
                    .foregroundColor(.appTextSecondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Spacer()

            Text(value)
                .font(.system(size: size == .small ? 24 : 36, weight: .black))
                .foregroundColor(.appTextPrimary)

            Text(subtitle)
                .font(size == .small ? .caption2 : .caption)
                .foregroundColor(.appTextTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: size == .small ? 110 : 140)
        .padding(size == .small ? 14 : 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .shadow(color: gradientColors[0].opacity(0.12), radius: 12, x: 0, y: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [gradientColors[0].opacity(0.3), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    enum CardSize {
        case small, medium, large
    }

    // MARK: - Achievement Gallery

    private var achievementGallery: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Achievements")
                    .font(.headline.bold())
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Button(action: { showAchievements.toggle() }) {
                    Text("View All")
                        .font(.subheadline.bold())
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    achievementBadge(
                        icon: "🔥",
                        title: "On Fire",
                        subtitle: "7 day streak",
                        gradientColors: [Color.orange, Color.red],
                        isUnlocked: currentStreak >= 7
                    )

                    achievementBadge(
                        icon: "⚡️",
                        title: "Lightning",
                        subtitle: "100% progress",
                        gradientColors: [Color.appAccent, Color.yellow],
                        isUnlocked: progressPercentage >= 1.0
                    )

                    achievementBadge(
                        icon: "💎",
                        title: "Diamond",
                        subtitle: "30 day streak",
                        gradientColors: [Color.cyan, Color.blue],
                        isUnlocked: currentStreak >= 30
                    )

                    achievementBadge(
                        icon: "👑",
                        title: "Legendary",
                        subtitle: "60 day streak",
                        gradientColors: [Color.purple, Color.pink],
                        isUnlocked: currentStreak >= 60
                    )

                    achievementBadge(
                        icon: "🌟",
                        title: "Rising Star",
                        subtitle: "10 days total",
                        gradientColors: [Color.yellow, Color.orange],
                        isUnlocked: totalDays >= 10
                    )
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private func achievementBadge(icon: String, title: String, subtitle: String, gradientColors: [Color], isUnlocked: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack {
                // Gradient background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: isUnlocked ? gradientColors : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .shadow(color: isUnlocked ? gradientColors[0].opacity(0.4) : Color.clear, radius: 12, x: 0, y: 6)

                // Icon
                Text(icon)
                    .font(.system(size: 36))
                    .grayscale(isUnlocked ? 0 : 1)
                    .opacity(isUnlocked ? 1.0 : 0.5)

                // Lock overlay for locked achievements
                if !isUnlocked {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .frame(width: 72, height: 72)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }

            VStack(spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundColor(isUnlocked ? .appTextPrimary : .appTextTertiary)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(.appTextTertiary)
            }
        }
        .frame(width: 100)
    }

    // MARK: - Premium Heatmap Calendar

    private var premiumHeatmapCalendar: some View {
        VStack(spacing: 20) {
            HStack {
                Text("Activity Heatmap")
                    .font(.headline.bold())
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Text(monthYearString(from: currentMonth))
                    .font(.subheadline.bold())
                    .foregroundColor(.appTextSecondary)
            }

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
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(calendarDays, id: \.self) { date in
                    heatmapDayCell(for: date)
                }
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.appCardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 20, x: 0, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.appAccent.opacity(0.2),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
    }

    private func heatmapDayCell(for date: Date?) -> some View {
        Group {
            if let date = date {
                let dayNumber = Calendar.current.component(.day, from: date)
                let isCompleted = completedDates.contains(where: { Calendar.current.isDate($0, inSameDayAs: date) })
                let isToday = Calendar.current.isDateInToday(date)

                ZStack {
                    // Background
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isCompleted ?
                            LinearGradient(
                                colors: [Color.appAccent.opacity(0.3), Color.orange.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                colors: [Color.appProgressTrack.opacity(0.3), Color.appProgressTrack.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)

                    // Today's ring
                    if isToday {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                            .frame(width: 42, height: 42)
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
                    } else {
                        Text("\(dayNumber)")
                            .font(.system(size: 15, weight: isToday ? .bold : .medium))
                            .foregroundColor(.appTextPrimary)
                    }
                }
                .frame(width: 42, height: 42)
            } else {
                Color.clear.frame(width: 42, height: 42)
            }
        }
    }

    // MARK: - Progress Categories

    private var progressCategories: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Performance Metrics")
                    .font(.headline.bold())
                    .foregroundColor(.appTextPrimary)

                Spacer()
            }

            VStack(spacing: 14) {
                categoryProgressBar(
                    title: "Consistency",
                    subtitle: "Showing up regularly",
                    value: consistencyScore,
                    icon: "calendar.badge.checkmark",
                    color: Color.blue
                )

                categoryProgressBar(
                    title: "Growth Rate",
                    subtitle: "Improvement over time",
                    value: growthScore,
                    icon: "chart.line.uptrend.xyaxis",
                    color: Color.green
                )

                categoryProgressBar(
                    title: "Peak Performance",
                    subtitle: "Best days achieved",
                    value: peakScore,
                    icon: "star.fill",
                    color: Color.purple
                )
            }
        }
    }

    private func categoryProgressBar(title: String, subtitle: String, value: Double, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(color)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(color.opacity(0.15))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline.bold())
                            .foregroundColor(.appTextPrimary)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.appTextSecondary)
                    }
                }

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(color)
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.appProgressTrack.opacity(0.3))
                        .frame(height: 8)

                    // Fill with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * (animateProgress ? value : 0), height: 8)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.3), value: animateProgress)
                }
            }
            .frame(height: 8)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.appCardBackground)
                .shadow(color: color.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Computed Properties

    private var currentStreak: Int {
        meterDataManager.meterData?.streak ?? 0
    }

    private var longestStreak: Int {
        calculateLongestStreak(from: allCompletedDates)
    }

    private var totalDays: Int {
        completedDates.count
    }

    private var currentLevel: Int {
        min(Int(Double(currentStreak) / 7.0) + 1, 99)
    }

    private var userRank: Int {
        max(100 - (currentStreak * 2), 5)
    }

    private var totalAchievements: Int {
        var count = 0
        if currentStreak >= 7 { count += 1 }
        if progressPercentage >= 1.0 { count += 1 }
        if currentStreak >= 30 { count += 1 }
        if currentStreak >= 60 { count += 1 }
        if totalDays >= 10 { count += 1 }
        return count
    }

    private var progressPercentage: Double {
        let progress = Double(meterDataManager.meterData?.progress ?? 0) / 100.0
        return min(max(progress, 0.0), 1.0)
    }

    private var growthRate: Int {
        min(currentStreak * 3, 99)
    }

    private var consistencyScore: Double {
        let score = Double(currentStreak) / 30.0
        return min(max(score, 0.0), 1.0)
    }

    private var growthScore: Double {
        let score = Double(currentStreak) / 60.0
        return min(max(score, 0.0), 1.0)
    }

    private var peakScore: Double {
        progressPercentage
    }

    // MARK: - Helper Functions

    private func particleOffset(for index: Int) -> CGPoint {
        let angle = Double(index) * (360.0 / 3.0) + (animateProgress ? 360 : 0)
        let radius: CGFloat = 100
        return CGPoint(
            x: cos(angle * .pi / 180) * radius,
            y: sin(angle * .pi / 180) * radius
        )
    }

    private func loadCompletedDates() async {
        guard let userId = supabase.userId else { return }

        isLoading = true

        do {
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

            // Fetch current month dates for calendar display
            let tasks: [CompletedTask] = try await supabase.client
                .from("daily_tasks")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

            completedDates = tasks.compactMap { task in
                dateFormatter.date(from: task.date)
            }

            // Fetch ALL completed dates for longest streak calculation
            let allTasks: [CompletedTask] = try await supabase.client
                .from("daily_tasks")
                .select()
                .eq("user_id", value: userId)
                .not("completed_at", operator: .is, value: "null")
                .order("date", ascending: true)
                .execute()
                .value

            allCompletedDates = allTasks.compactMap { task in
                dateFormatter.date(from: task.date)
            }

        } catch {
            print("❌ Load completed dates error: \(error)")
        }

        isLoading = false
    }

    // Calculate longest streak from completed dates
    private func calculateLongestStreak(from dates: [Date]) -> Int {
        guard !dates.isEmpty else { return 0 }

        let sortedDates = dates.sorted()
        var longestStreak = 1
        var currentStreakCount = 1
        let calendar = Calendar.current

        for i in 1..<sortedDates.count {
            let previousDate = calendar.startOfDay(for: sortedDates[i-1])
            let currentDate = calendar.startOfDay(for: sortedDates[i])

            // Check if dates are consecutive (1 day apart)
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previousDate),
               calendar.isDate(nextDay, inSameDayAs: currentDate) {
                currentStreakCount += 1
                longestStreak = max(longestStreak, currentStreakCount)
            } else if !calendar.isDate(previousDate, inSameDayAs: currentDate) {
                // Reset streak if dates are not consecutive and not the same day
                currentStreakCount = 1
            }
        }

        return longestStreak
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDayOfMonth = calendar.date(from: components) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: firstDayOfMonth)?.count ?? 0

        var days: [Date?] = []

        for _ in 1..<firstWeekday {
            days.append(nil)
        }

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
