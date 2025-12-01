import SwiftUI
import Combine
import Supabase

struct DashboardView: View {
    @StateObject private var hackViewModel = DailyHackViewModel()
    @EnvironmentObject var meterDataManager: MeterDataManager
    
    // Appearance override (System/Light/Dark)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var errorText: String?
    @State private var isCardExpanded = false
    @State private var weekDays: [(day: String, date: Int, isCompleted: Bool)] = []
    @State private var showListenMode = false
    @State private var showReadMode = false
    @State private var pulse = false
    
    private var supabase: SupabaseManager { SupabaseManager.shared }
    
    // Computed color scheme based on user preference
    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil // System
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Adaptive background (warm off-white in light, black in dark)
                Color.appBackground.ignoresSafeArea()
                
                // Subtle depth gradient (only in dark mode)
                darkModeDepthGradient

                ScrollView {
                    VStack(spacing: 30) {
                        Text("Brain level")
                            .font(.title2.bold())
                            .foregroundColor(.appTextPrimary)
                            .padding(.top, 20)

                        meterSection

                        streakCalendarView
                            .padding(.horizontal)

                        todayHackCard
                            .padding(.horizontal)

                        errorSection
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(preferredColorScheme) // Apply user preference
            .task {
                // ✅ Data should already be pre-fetched during animation!
                // These calls will use cached data (instant, no network call)
                if meterDataManager.meterData == nil {
                    print("⚠️ Cache miss: Meter data not found (pre-fetch may have failed)")
                    await meterDataManager.fetchMeterData()
                } else {
                    print("⚡️ Using pre-fetched meter data - INSTANT!")
                }
                
                // This will use cached hack data if available (see DailyHackViewModel)
                await hackViewModel.loadTodaysHack()
            }
            .refreshable {
                await meterDataManager.fetchMeterData(force: true)
                await hackViewModel.loadTodaysHack()
                generateWeekData()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshDashboard"))) { _ in
                Task {
                    await meterDataManager.fetchMeterData(force: true)
                    await hackViewModel.loadTodaysHack()
                    generateWeekData()
                }
            }
            .onAppear {
                generateWeekData()
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
            .onChange(of: meterDataManager.isTodayHackComplete) { _ in
                generateWeekData()
            }
        }
        .fullScreenCover(isPresented: $showListenMode) {
            if let hack = hackViewModel.todaysHack {
                DailyHackView(
                    autoPlayVoice: true,
                    preloadedHack: hack,
                    preGeneratedAudioUrls: hack.audioUrls ?? []
                )
            }
        }
        .fullScreenCover(isPresented: $showReadMode) {
            if let hack = hackViewModel.todaysHack {
                DailyHackView(
                    autoPlayVoice: false,
                    preloadedHack: hack,
                    preGeneratedAudioUrls: hack.audioUrls ?? []
                )
            }
        }
    }
    
    // MARK: - Dark Mode Depth Gradient (only shows in dark mode)
    @ViewBuilder
    private var darkModeDepthGradient: some View {
        // Only add radial gradient in dark mode for depth
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
        .opacity(colorScheme == .dark ? 1 : 0)
    }
    
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Meter Section
    @ViewBuilder
    private var meterSection: some View {
        if let data = meterDataManager.meterData {
            circularProgressView(data: data)
        } else if meterDataManager.isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.appAccent)
                .padding()
        }
    }
    
    // MARK: - Error Section
    @ViewBuilder
    private var errorSection: some View {
        if let error = meterDataManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding()
        }
    }

    // MARK: - Hack Card
    private var todayHackCard: some View {
        VStack(spacing: 0) {
            hackCardMainButton
            
            if isCardExpanded {
                hackCardExpandedContent
            }
        }
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 10, y: 5)
    }
    
    // Shadow adapts to mode
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.08)
    }
    
    // Hack Card - Main Button
    private var hackCardMainButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isCardExpanded.toggle()
            }
        } label: {
            hackCardContent
        }
    }
    
    // Hack Card - Content
    private var hackCardContent: some View {
        ZStack {
            hackCardBackground
            hackCardOverlay
            hackCardText
        }
        .frame(height: 140)
    }
    
    // Hack Card - Background Image
    private var hackCardBackground: some View {
        AsyncImage(url: URL(string: ImageService.getTodaysImage())) { phase in
            if case .success(let image) = phase {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Fallback gradient
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(white: 0.08), Color(white: 0.04)]
                        : [Color(hex: "#FFE7D6"), Color(hex: "#FFF8F0")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(height: 140)
        .clipped()
    }
    
    // Hack Card - Dark Overlay
    private var hackCardOverlay: some View {
        LinearGradient(
            colors: [Color.black.opacity(0.50), Color.black.opacity(0.80)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
    
    // Hack Card - Text Content
    private var hackCardText: some View {
        VStack(alignment: .leading, spacing: 12) {
            hackCardHeader
            Spacer()
            hackCardTitle
            hackCardTags
        }
        .padding()
    }
    
    // Hack Card - Header Row
    private var hackCardHeader: some View {
        HStack {
            if meterDataManager.isTodayHackComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.appAccent)
                    .shadow(color: Color.appAccent.opacity(0.6), radius: 4)
            }

            Text("TODAY'S BRAIN HACK • 1 MIN")
                .font(.caption.bold())
                .foregroundColor(.white)

            Spacer()

            Image(systemName: isCardExpanded ? "chevron.up" : "chevron.down")
                .foregroundColor(.white.opacity(0.7))
                .font(.title3)
        }
    }
    
    // Hack Card - Title
    @ViewBuilder
    private var hackCardTitle: some View {
        if let hack = hackViewModel.todaysHack {
            Text(hack.hackName)
                .font(.headline)
                .foregroundColor(.white)
                .lineLimit(isCardExpanded ? nil : 2)
        } else if hackViewModel.errorMessage != nil {
            Text("Tap to try again")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.85))
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.white)
                Text("Loading your hack...")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
            }
        }
    }
    
    // Hack Card - Tags
    private var hackCardTags: some View {
        HStack(spacing: 8) {
            miniTag(text: "FOCUS")
            miniTag(text: "DISCIPLINE")
            miniTag(text: "MOTIVATION")
        }
    }
    
    // Hack Card - Expanded Content
    private var hackCardExpandedContent: some View {
        VStack(spacing: 16) {
            if hackViewModel.todaysHack != nil {
                HStack(spacing: 12) {
                    listenButton
                    readButton
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .background(Color.appGlassOverlay)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // Listen Button (Primary - Gold Accent)
    private var listenButton: some View {
        Button {
            showListenMode = true
        } label: {
            HStack {
                Image(systemName: "headphones")
                Text("Listen")
            }
            .font(.subheadline.bold())
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appAccent)
            .cornerRadius(12)
            .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
        }
    }
    
    // Read Button (Secondary - Glass)
    private var readButton: some View {
        Button {
            showReadMode = true
        } label: {
            HStack {
                Image(systemName: "book")
                Text("Read")
            }
            .font(.subheadline.bold())
            .foregroundColor(.appTextPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.appGlassOverlay)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.appCardBorder, lineWidth: 1)
            )
        }
    }

    private func miniTag(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(6)
    }

    // MARK: - Circular Progress
    private func circularProgressView(data: MeterResponse) -> some View {
        VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.appProgressTrack, lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))

                // Progress arc
                Circle()
                    .trim(from: 0, to: (data.progress / 100) * 0.75)
                    .stroke(
                        Color.appAccent,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))
                    .shadow(color: progressGlowColor, radius: 10)
                    .shadow(color: progressGlowColor, radius: 20)
                    .animation(.easeInOut(duration: 1.0), value: data.progress)

                VStack(spacing: 4) {
                    Text("\(Int(data.progress))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.appTextPrimary)

                    Text("Rewired")
                        .font(.subheadline)
                        .foregroundColor(.appTextSecondary)
                }
            }
        }
    }
    
    // Glow only in dark mode
    private var progressGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.5) : Color.clear
    }

    // MARK: - Streak Calendar
    private var streakCalendarView: some View {
        VStack(spacing: 16) {
            weekDaysHeader
            weekDaysGrid
        }
        .padding()
        .background(Color.appCardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.appCardBorder, lineWidth: 1)
        )
    }
    
    // Week Days Header
    private var weekDaysHeader: some View {
        HStack(spacing: 0) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundColor(.appTextTertiary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Week Days Grid
    private var weekDaysGrid: some View {
        HStack(spacing: 0) {
            ForEach(weekDays, id: \.date) { dayData in
                dayCircle(dayData: dayData)
                    .frame(maxWidth: .infinity)
            }
        }
    }
    
    // Individual Day Circle
    private func dayCircle(dayData: (day: String, date: Int, isCompleted: Bool)) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(dayData.isCompleted ? Color.appAccent.opacity(0.12) : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(
                            dayData.isCompleted ? Color.appAccent : Color.appCardBorder,
                            lineWidth: dayData.isCompleted ? 2.5 : 1.5
                        )
                    )
                    .shadow(
                        color: dayData.isCompleted ? dayGlowColor : .clear,
                        radius: dayData.isCompleted ? 8 : 0
                    )

                if dayData.isCompleted {
                    completedDayBolt
                } else {
                    Text("\(dayData.date)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.appTextPrimary)
                }
            }
            .frame(width: 44, height: 44)
            Color.clear.frame(height: 20)
        }
    }
    
    // Day glow only in dark mode
    private var dayGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.4) : Color.clear
    }
    
    // Completed Day Lightning Bolt
    private var completedDayBolt: some View {
        Image(systemName: "bolt.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundColor(.appAccent)
            .shadow(color: boltGlowColor, radius: 6)
            .overlay(
                Circle()
                    .stroke(Color.appAccent.opacity(0.3), lineWidth: 2)
                    .scaleEffect(pulse ? 1.2 : 0.95)
                    .opacity(pulse ? 0.0 : 0.7)
            )
    }
    
    // Bolt glow stronger in dark mode
    private var boltGlowColor: Color {
        colorScheme == .dark ? Color.appAccent.opacity(0.8) : Color.appAccent.opacity(0.3)
    }

    private func generateWeekData() {
        let calendar = Calendar.current
        let today = Date()

        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else { return }

        weekDays = (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                return (day: "", date: 0, isCompleted: false)
            }

            let dayNumber = calendar.component(.day, from: date)
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let isCompleted = calendar.isDate(date, inSameDayAs: today) && meterDataManager.isTodayHackComplete

            return (day: String(dayName.prefix(1)), date: dayNumber, isCompleted: isCompleted)
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(MeterDataManager.shared)
}
