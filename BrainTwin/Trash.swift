import SwiftUI
import Combine
import Supabase

struct DashboardViewB: View {
    @StateObject private var hackViewModel = DailyHackViewModel()
    @EnvironmentObject var meterDataManager: MeterDataManager
    @State private var errorText: String?
    @State private var isCardExpanded = false
    @State private var weekDays: [(day: String, date: Int, isCompleted: Bool)] = []

    @State private var showListenMode = false
    @State private var showReadMode = false
    @State private var pulse = false

    // 🎨 NEURAL DEEP BLACK - Premium Minimal Design
    private let neuralAccent = Color(red: 1.0, green: 0.84, blue: 0.04) // Electric Yellow #FFD60A
    private var supabase: SupabaseManager { SupabaseManager.shared }

    var body: some View {
        NavigationStack {
            ZStack {
                // Pure black background
                Color.black.ignoresSafeArea()
                
                // Subtle radial depth
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

                ScrollView {
                    VStack(spacing: 30) {
                        Text("Brain level")
                            .font(.title2.bold())
                            .foregroundColor(.white)
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
            .task {
                if meterDataManager.meterData == nil {
                    await meterDataManager.fetchMeterData()
                }
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
    
    // MARK: - Meter Section (fixes type-checking)
    @ViewBuilder
    private var meterSection: some View {
        if let data = meterDataManager.meterData {
            circularProgressView(data: data)
        } else if meterDataManager.isLoading {
            ProgressView()
                .scaleEffect(1.5)
                .tint(neuralAccent)
                .padding()
        }
    }
    
    // MARK: - Error Section (fixes type-checking)
    @ViewBuilder
    private var errorSection: some View {
        if let error = meterDataManager.errorMessage {
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
                .padding()
        }
    }

    // MARK: - Hack Card (BROKEN INTO SMALLER PIECES)
    private var todayHackCard: some View {
        VStack(spacing: 0) {
            hackCardMainButton
            
            if isCardExpanded {
                hackCardExpandedContent
            }
        }
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 5)
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
                LinearGradient(
                    colors: [Color(white: 0.08), Color(white: 0.04)],
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
                    .foregroundColor(neuralAccent)
                    .shadow(color: neuralAccent.opacity(0.6), radius: 4)
            }

            Text("YOUR BRAIN HACK • 1 MIN")
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
        .background(Color.white.opacity(0.02))
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    // Listen Button
    private var listenButton: some View {
        Button {
            showListenMode = true
        } label: {
            HStack {
                Image(systemName: "headphones")
                Text("Listen")
            }
            .font(.subheadline.bold())
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(neuralAccent)
            .cornerRadius(12)
            .shadow(color: neuralAccent.opacity(0.4), radius: 8)
        }
    }
    
    // Read Button
    private var readButton: some View {
        Button {
            showReadMode = true
        } label: {
            HStack {
                Image(systemName: "book")
                Text("Read")
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func miniTag(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.12))
            .cornerRadius(6)
    }

    // MARK: - Circular Progress
    private func circularProgressView(data: MeterResponse) -> some View {
        VStack(spacing: 20) {
            ZStack {
                // Background track
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.08), lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))

                // Progress arc with glow
                Circle()
                    .trim(from: 0, to: (data.progress / 100) * 0.75)
                    .stroke(
                        neuralAccent,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))
                    .shadow(color: neuralAccent.opacity(0.6), radius: 10)
                    .shadow(color: neuralAccent.opacity(0.4), radius: 20)
                    .animation(.easeInOut(duration: 1.0), value: data.progress)

                VStack(spacing: 4) {
                    Text("\(Int(data.progress))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)

                    Text("Rewired")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
    }

    // MARK: - Streak Calendar
    private var streakCalendarView: some View {
        VStack(spacing: 16) {
            weekDaysHeader
            weekDaysGrid
        }
        .padding()
        .background(Color.white.opacity(0.03))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // Week Days Header
    private var weekDaysHeader: some View {
        HStack(spacing: 0) {
            ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                Text(day)
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.4))
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
                    .fill(dayData.isCompleted ? neuralAccent.opacity(0.12) : Color.clear)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle().stroke(
                            dayData.isCompleted ? neuralAccent : Color.white.opacity(0.15),
                            lineWidth: dayData.isCompleted ? 2.5 : 1.5
                        )
                    )
                    .shadow(
                        color: dayData.isCompleted ? neuralAccent.opacity(0.4) : .clear,
                        radius: dayData.isCompleted ? 8 : 0
                    )

                if dayData.isCompleted {
                    completedDayBolt
                } else {
                    Text("\(dayData.date)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(width: 44, height: 44)
            Color.clear.frame(height: 20)
        }
    }
    
    // Completed Day Lightning Bolt
    private var completedDayBolt: some View {
        Image(systemName: "bolt.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
            .foregroundColor(neuralAccent)
            .shadow(color: neuralAccent.opacity(0.8), radius: 6)
            .overlay(
                Circle()
                    .stroke(neuralAccent.opacity(0.3), lineWidth: 2)
                    .scaleEffect(pulse ? 1.2 : 0.95)
                    .opacity(pulse ? 0.0 : 0.7)
            )
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
