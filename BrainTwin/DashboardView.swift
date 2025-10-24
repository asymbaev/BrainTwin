import SwiftUI
import Combine
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

    // Full-screen covers
    @State private var showListenMode = false
    @State private var showReadMode = false

    // Live time for adaptive background
    @State private var now = Date()
    private var clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    // Pulse anim for completed lightning
    @State private var pulse = false

    // Brand lightning blue
    private let lightningBlue = Color(red: 0.45, green: 0.65, blue: 0.95)

    // MARK: - Time-Based Gradient (Yellow + Blue/Purple, 2 stops)
    private var neuroHarmonicGradient: LinearGradient {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 6..<12: // Morning
            return LinearGradient(
                colors: [
                    Color(red: 1.00, green: 0.92, blue: 0.65), // soft gold
                    Color(red: 0.58, green: 0.75, blue: 1.00)  // pastel sky blue
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 12..<18: // Afternoon
            return LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.80, blue: 0.45), // honey yellow
                    Color(red: 0.45, green: 0.65, blue: 0.95)  // focus blue
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case 18..<22: // Evening
            return LinearGradient(
                colors: [
                    Color(red: 0.90, green: 0.65, blue: 0.40), // amber
                    Color(red: 0.45, green: 0.40, blue: 0.75)  // deep violet
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        default: // Night
            return LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.18, blue: 0.35),                      // deep navy
                    Color(red: 0.90, green: 0.80, blue: 0.45).opacity(0.28)         // muted gold glow
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                neuroHarmonicGradient
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 1.6), value: now)

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
            .onReceive(clock) { newDate in
                now = newDate
            }
            .onAppear {
                // start pulse animation once
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    pulse = true
                }
            }
        }
        // Full-screen covers
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

    // MARK: - Card

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
                            image.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.95, green: 0.80, blue: 0.45),
                                    Color(red: 0.45, green: 0.65, blue: 0.95)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .frame(height: 140)
                    .clipped()

                    LinearGradient(
                        colors: [Color.black.opacity(0.30), Color.black.opacity(0.70)],
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
                    .stroke(Color.white.opacity(0.10), lineWidth: 20)
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(135))

                Circle()
                    .trim(from: 0, to: (data.progress / 100) * 0.75)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.95, green: 0.80, blue: 0.45),
                                Color(red: 0.45, green: 0.65, blue: 0.95)
                            ],
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

    // MARK: - Streak Calendar (BIG LIGHTNING replaces date on completed day)
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
                            // Filled/outlined circle
                            Circle()
                                .fill(dayData.isCompleted ? lightningBlue.opacity(0.15) : Color.clear)
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Circle().stroke(
                                        dayData.isCompleted ? lightningBlue : Color.white.opacity(0.30),
                                        lineWidth: dayData.isCompleted ? 2.5 : 2
                                    )
                                )
                                .shadow(color: dayData.isCompleted ? lightningBlue.opacity(0.45) : .clear,
                                        radius: dayData.isCompleted ? 6 : 0)

                            if dayData.isCompleted {
                                // BIG centered bolt replaces date
                                Image(systemName: "bolt.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20) // bigger icon
                                    .foregroundColor(lightningBlue)
                                    .shadow(color: lightningBlue.opacity(0.7), radius: 4)
                                    // gentle expanding ring pulse
                                    .overlay(
                                        Circle()
                                            .stroke(lightningBlue.opacity(0.45), lineWidth: 2)
                                            .scaleEffect(pulse ? 1.18 : 0.95)
                                            .opacity(pulse ? 0.0 : 0.7)
                                    )
                            } else {
                                // Normal date for not-completed days
                                Text("\(dayData.date)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(width: 44, height: 44)

                        // spacer below row (no emoji)
                        Color.clear.frame(height: 20)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }

    // MARK: - Data helpers
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

            // NOTE: your existing logic: only mark TODAY as completed if today's hack is done
            let isCompleted = calendar.isDate(date, inSameDayAs: today) && isTodayHackComplete
            return (day: String(dayName.prefix(1)), date: dayNumber, isCompleted: isCompleted)
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
            struct MeterRequest: Encodable { let userId: String }
            let response: MeterResponse = try await supabase.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: MeterRequest(userId: userId))
            )
            meterData = response
        } catch {
            errorText = "Failed to load data: \(error.localizedDescription)"
        }

        isLoading = false
    }

    private func checkTodayCompletion() async {
        guard let userId = supabase.userId else { return }

        do {
            struct HackRequest: Encodable { let userId: String }
            struct HackResponse: Decodable { let isCompleted: Bool? }
            let response: HackResponse = try await supabase.client.functions.invoke(
                "generate-brain-hack",
                options: FunctionInvokeOptions(body: HackRequest(userId: userId))
            )
            isTodayHackComplete = response.isCompleted ?? false
        } catch {
            isTodayHackComplete = false
        }
    }
}

#Preview {
    DashboardView()
}
