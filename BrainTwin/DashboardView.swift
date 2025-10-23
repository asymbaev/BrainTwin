import SwiftUI
import Supabase

struct DashboardView: View {
    @StateObject private var supabase = SupabaseManager.shared
    @StateObject private var hackViewModel = DailyHackViewModel()
    @State private var meterData: MeterResponse?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var isTodayHackComplete = false
    @State private var isCardExpanded = false
    @State private var weekDays: [(day: String, date: Int, isCompleted: Bool)] = []
    
    // Add these for fullScreenCover
    @State private var showListenMode = false
    @State private var showReadMode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
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
                        Text("Brain level")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.top, 20)
                        
                        if let data = meterData {
                            circularProgressView(data: data)
                        } else if isLoading {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                                .padding()
                        }
                        
                        streakCalendarView
                            .padding(.horizontal)
                        
                        todayHackCard
                            .padding(.horizontal)
                        
                        if let error = errorText {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await hackViewModel.loadTodaysHack()
                print("🔍 Dashboard hack: \(hackViewModel.todaysHack?.hackName ?? "nil")")
                print("🔍 Has neuroscience: \(hackViewModel.todaysHack?.neuroscience != nil)")
                print("🔍 Has explanation: \(hackViewModel.todaysHack?.explanation != nil)")
                await fetchMeterData()
                await checkTodayCompletion()
                generateWeekData()
            }
            .refreshable {
                await hackViewModel.loadTodaysHack()
                await fetchMeterData()
                await checkTodayCompletion()
                generateWeekData()
            }
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshDashboard"))) { _ in
                Task {
                    await hackViewModel.loadTodaysHack()
                    await fetchMeterData()
                    await checkTodayCompletion()
                    generateWeekData()
                }
            }
        }
        // Add fullScreenCover modifiers here
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
    
    private var todayHackCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isCardExpanded.toggle()
                }
            } label: {
                ZStack {
                    AsyncImage(url: URL(string: ImageService.getTodaysImage())) { phase in
                        if case .success(let image) = phase {
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 140)
                    .clipped()
                    
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            if isTodayHackComplete {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            Text("YOUR BRAIN HACK • 1 MIN")
                                .font(.caption.bold())
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Image(systemName: isCardExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                                .font(.title3)
                        }
                        
                        Spacer()
                        
                        if let hack = hackViewModel.todaysHack {
                            Text(hack.hackName)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(isCardExpanded ? nil : 2)
                        } else if hackViewModel.errorMessage != nil {
                            Text("Tap to try again")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        } else {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(.white)
                                Text("Loading your hack...")
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        
                        HStack(spacing: 8) {
                            miniTag(text: "FOCUS")
                            miniTag(text: "DISCIPLINE")
                            miniTag(text: "MOTIVATION")
                        }
                    }
                    .padding()
                }
                .frame(height: 140)
            }
            
            if isCardExpanded {
                VStack(spacing: 16) {
                    if hackViewModel.todaysHack != nil {
                        HStack(spacing: 12) {
                            // Listen button - now uses state instead of NavigationLink
                            Button {
                                showListenMode = true
                            } label: {
                                HStack {
                                    Image(systemName: "headphones")
                                    Text("Listen")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                            
                            // Read button - now uses state instead of NavigationLink
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
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                    }
                }
                .background(Color.white.opacity(0.05))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func miniTag(text: String) -> some View {
        Text(text)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
    }
    
    private func circularProgressView(data: MeterResponse) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(Color.white.opacity(0.1), lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))
                
                Circle()
                    .trim(from: 0, to: (data.progress / 100) * 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [Color.green, Color(red: 0.5, green: 0.8, blue: 0.3)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))
                    .animation(.easeInOut(duration: 1.0), value: data.progress)
                
                VStack(spacing: 4) {
                    Text("\(Int(data.progress))%")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Rewired")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var streakCalendarView: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(maxWidth: .infinity)
                }
            }
            
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.date) { dayData in
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .stroke(
                                    dayData.isCompleted ? Color.yellow : Color.white.opacity(0.3),
                                    lineWidth: 2
                                )
                                .frame(width: 44, height: 44)
                            
                            if dayData.isCompleted {
                                Circle()
                                    .fill(Color.yellow.opacity(0.2))
                                    .frame(width: 44, height: 44)
                            }
                            
                            Text("\(dayData.date)")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        
                        if dayData.isCompleted {
                            Text("🔥")
                                .font(.system(size: 20))
                        } else {
                            Color.clear.frame(height: 20)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func generateWeekData() {
        let calendar = Calendar.current
        let today = Date()
        
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
            return
        }
        
        weekDays = (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else {
                return (day: "", date: 0, isCompleted: false)
            }
            
            let dayNumber = calendar.component(.day, from: date)
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let isCompleted = dayOffset < calendar.component(.weekday, from: today) - 1 && (meterData?.streak ?? 0) > 0
            
            return (day: String(dayName.prefix(1)), date: dayNumber, isCompleted: isCompleted || calendar.isDate(date, inSameDayAs: today) && isTodayHackComplete)
        }
    }
    
    private func fetchMeterData() async {
        guard let userId = supabase.userId else {
            errorText = "No user ID found"
            return
        }
        
        isLoading = true
        errorText = nil
        
        do {
            print("📊 Fetching meter data for user: \(userId)")
            
            struct MeterRequest: Encodable {
                let userId: String
            }
            
            let request = MeterRequest(userId: userId)
            
            let response: MeterResponse = try await supabase.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: request)
            )
            
            print("✅ Meter data received: \(response.progress)% progress")
            
            meterData = response
            
        } catch {
            print("❌ Fetch meter error: \(error)")
            errorText = "Failed to load data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func checkTodayCompletion() async {
        guard let userId = supabase.userId else { return }
        
        do {
            struct HackRequest: Encodable {
                let userId: String
            }
            
            struct HackResponse: Decodable {
                let isCompleted: Bool?
            }
            
            let request = HackRequest(userId: userId)
            
            let response: HackResponse = try await supabase.client.functions.invoke(
                "generate-brain-hack",
                options: FunctionInvokeOptions(body: request)
            )
            
            isTodayHackComplete = response.isCompleted ?? false
            
            print(isTodayHackComplete ? "✅ Today's hack completed" : "⏳ Today's hack not completed")
            
        } catch {
            print("❌ Check completion error: \(error)")
            isTodayHackComplete = false
        }
    }
}

#Preview {
    DashboardView()
}
