import SwiftUI
import Combine
import Supabase

struct ProfileSetupAnimationView: View {
    @Binding var isComplete: Bool
    @Environment(\.colorScheme) var colorScheme
    
    // ✅ Appearance override (same as other views)
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    
    @State private var progress: Double = 0.0
    @State private var currentMessage = "Analyzing your goals..."
    
    // ✅ Background task tracking
    @State private var taskProgress: [String: Bool] = [
        "generateHack": false,
        "calculateMeter": false,
        "preloadDashboard": false,
        "loadWeekCalendar": false
    ]
    @State private var errorOccurred = false
    @State private var retryCount = 0
    private let maxRetries = 3

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
            // ✅ Adaptive background
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
            
            // ✅ Growing Neural Network Animation
            GrowingNeuralNetworkAnimation(progress: progress)

            VStack(spacing: 34) {
                Spacer()

                // Headline
                Text(currentMessage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Color.appTextPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .transition(.opacity.combined(with: .scale))
                    .animation(.easeInOut(duration: 0.3), value: currentMessage)

                // Percentage
                Text("\(Int(progress))%")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(Color.appTextPrimary)
                    .monospacedDigit()

                // Progress bar (adaptive)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appCardBorder)
                            .frame(height: 8)

                        // Filled progress
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.appAccent)
                            .frame(width: geo.size.width * (progress / 100), height: 8)
                            .animation(.linear(duration: 0.25), value: progress)

                        // Shimmer effect on progress
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.clear, .white.opacity(0.4), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: 100, height: 8)
                            .offset(x: (geo.size.width * (progress / 100)) - 50)
                    }
                }
                .frame(height: 8)
                .padding(.horizontal, 40)

                // Status text
                if errorOccurred && retryCount < maxRetries {
                    Text("Having trouble connecting... retrying")
                        .font(.caption)
                        .foregroundStyle(Color.orange)
                } else {
                    Text("This may take up to a minute")
                        .font(.caption)
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer(minLength: 80)
            }
        }
        .preferredColorScheme(preferredColorScheme)
        .onAppear {
            startBackgroundTasks()
        }
    }

    // MARK: - Background Tasks Logic
    
    private func startBackgroundTasks() {
        print("🚀 Starting background tasks for profile setup...")
        
        Task {
            // Run all 4 tasks in parallel
            await withTaskGroup(of: (String, Bool).self) { group in
                // Task 1: Generate first brain hack
                group.addTask {
                    await ("generateHack", generateBrainHack())
                }
                
                // Task 2: Calculate meter (initialize progress)
                group.addTask {
                    await ("calculateMeter", calculateMeter())
                }
                
                // Task 3: Preload dashboard data (meter + completion status)
                group.addTask {
                    await ("preloadDashboard", preloadDashboardData())
                }
                
                // Task 4: Load week calendar data
                group.addTask {
                    await ("loadWeekCalendar", loadWeekCalendar())
                }
                
                // Collect results and update progress
                for await (taskName, success) in group {
                    await MainActor.run {
                        taskProgress[taskName] = success
                        updateProgress()
                        print("✅ Task completed: \(taskName) - Success: \(success)")
                    }
                }
            }
            
            // All tasks complete - finalize
            await MainActor.run {
                if allTasksComplete {
                    finalizeSetup()
                } else if retryCount < maxRetries {
                    // Retry failed tasks
                    retryFailedTasks()
                } else {
                    // Max retries reached - allow user to continue anyway
                    print("⚠️ Some tasks failed after max retries, allowing user to continue")
                    finalizeSetup()
                }
            }
        }
    }
    
    // MARK: - Individual Task Functions
    
    /// Task 1: Generate first brain hack based on user's goal
    private func generateBrainHack() async -> Bool {
        guard let userId = SupabaseManager.shared.userId else {
            print("❌ No user ID for brain hack generation")
            return false
        }
        
        do {
            print("🧠 Generating first brain hack...")
            
            // Call the generate-brain-hack function
            let response: BrainHackResponse = try await SupabaseManager.shared.client.functions.invoke(
                "generate-brain-hack",
                options: .init(body: ["userId": userId] as [String: String])
            )
            
            print("✅ Brain hack generated: \(response.hackName)")
            return true
            
        } catch {
            print("❌ Brain hack generation failed: \(error)")
            return false
        }
    }
    
    /// Task 2: Initialize rewire meter
    private func calculateMeter() async -> Bool {
        guard let userId = SupabaseManager.shared.userId else {
            print("❌ No user ID for meter calculation")
            return false
        }
        
        do {
            print("📊 Calculating initial meter data...")
            
            let _: MeterResponse = try await SupabaseManager.shared.getMeterData(userId: userId)
            
            print("✅ Meter calculated successfully")
            return true
            
        } catch {
            print("❌ Meter calculation failed: \(error)")
            return false
        }
    }
    
    /// Task 3: Preload dashboard data using MeterDataManager
    private func preloadDashboardData() async -> Bool {
        print("📦 Preloading dashboard data...")
        
        await MeterDataManager.shared.fetchMeterData(force: true)
        
        if MeterDataManager.shared.meterData != nil {
            print("✅ Dashboard data preloaded successfully")
            return true
        } else {
            print("❌ Dashboard data preload failed")
            return false
        }
    }
    
    /// Task 4: Load week calendar data for dashboard
    private func loadWeekCalendar() async -> Bool {
        guard let userId = SupabaseManager.shared.userId else {
            print("❌ No user ID for week calendar")
            return false
        }
        
        do {
            print("📅 Loading week calendar data...")
            
            // Get current week dates
            let calendar = Calendar.current
            let today = Date()
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
                return false
            }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            
            let startDateString = formatter.string(from: weekStart)
            let endDate = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? today
            let endDateString = formatter.string(from: endDate)
            
            // Fetch completed dates for this week
            let _: [WeekTask] = try await SupabaseManager.shared.client
                .from("daily_tasks")
                .select()
                .eq("user_id", value: userId)
                .gte("date", value: startDateString)
                .lte("date", value: endDateString)
                .not("completed_at", operator: .is, value: "null")
                .execute()
                .value
            
            print("✅ Week calendar data loaded successfully")
            return true
            
        } catch {
            print("❌ Week calendar load failed: \(error)")
            // Non-critical error - new users will have empty calendar anyway
            return true // Return true to not block progress
        }
    }
    
    // MARK: - Progress Management
    
    private func updateProgress() {
        let completedTasks = taskProgress.values.filter { $0 }.count
        let totalTasks = taskProgress.count
        
        // Calculate progress (each task = 25%)
        let calculatedProgress = Double(completedTasks) * 25.0
        
        // Smooth animation
        withAnimation(.linear(duration: 0.5)) {
            progress = calculatedProgress
        }
        
        // Update message based on progress
        updateMessage(for: calculatedProgress)
    }
    
    private func updateMessage(for p: Double) {
        let newMessage: String
        
        switch p {
        case 0..<25:
            newMessage = "Analyzing your goals..."
        case 25..<50:
            newMessage = "Creating your personalized plan..."
        case 50..<75:
            newMessage = "Setting up your neural pathways..."
        case 75..<100:
            newMessage = "Finalizing your brain hack..."
        case 100:
            newMessage = "Almost ready..."
        default:
            newMessage = currentMessage
        }
        
        if newMessage != currentMessage {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentMessage = newMessage
            }
        }
    }
    
    private var allTasksComplete: Bool {
        taskProgress.values.allSatisfy { $0 }
    }
    
    private func retryFailedTasks() {
        errorOccurred = true
        retryCount += 1
        
        print("⚠️ Retrying failed tasks (attempt \(retryCount)/\(maxRetries))...")
        
        // Reset failed tasks
        for (taskName, success) in taskProgress where !success {
            taskProgress[taskName] = false
        }
        
        // Wait 2 seconds before retrying
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            errorOccurred = false
            startBackgroundTasks()
        }
    }
    
    private func finalizeSetup() {
        // Ensure we're at 100%
        withAnimation(.linear(duration: 0.5)) {
            progress = 100
            currentMessage = "Almost ready..."
        }
        
        // Wait a moment before completing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("✅ Profile setup complete!")
            isComplete = true
        }
    }
}

// MARK: - Helper Types

struct BrainHackResponse: Codable {
    let hackName: String
    let quote: String
    let explanation: String
    let neuroscience: String
    let personalization: String?
    let barrier: String
    let isCompleted: Bool?
    let audioUrls: [String]?
}

struct WeekTask: Codable {
    let date: String
    let completed_at: String?
}

// MARK: - Growing Neural Network Animation
struct GrowingNeuralNetworkAnimation: View {
    let progress: Double
    @Environment(\.colorScheme) var colorScheme
    @State private var particles: [GrowingNeuron] = []
    @State private var screenSize: CGSize = .zero
    @State private var pulsePhase: Double = 0
    
    let timer = Timer.publish(every: 1/60, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let currentTime = Date().timeIntervalSinceReferenceDate
                let pulseIntensity = sin(pulsePhase * 2) * 0.5 + 0.5
                
                // Draw connections with pulsing effect
                let connectionDistance: CGFloat = 100 + CGFloat(progress * 0.5)
                for i in 0..<particles.count {
                    for j in (i+1)..<particles.count {
                        let dx = particles[i].x - particles[j].x
                        let dy = particles[i].y - particles[j].y
                        let distance = sqrt(dx * dx + dy * dy)
                        
                        if distance < connectionDistance {
                            let baseOpacity = 1 - (distance / connectionDistance)
                            let pulse = baseOpacity * (0.3 + pulseIntensity * 0.3)
                            
                            var path = Path()
                            path.move(to: CGPoint(x: particles[i].x, y: particles[i].y))
                            path.addLine(to: CGPoint(x: particles[j].x, y: particles[j].y))
                            
                            let connectionColor = colorScheme == .dark
                                ? Color.appAccent.opacity(pulse * 0.3)
                                : Color.appTextPrimary.opacity(pulse * 0.18)
                            
                            context.stroke(path, with: .color(connectionColor), lineWidth: 1.5)
                        }
                    }
                }
                
                // Draw particles with fade-in effect
                for particle in particles {
                    let age = currentTime - particle.birthTime
                    let fadeIn = min(age / 0.5, 1.0)
                    
                    let rect = CGRect(
                        x: particle.x - particle.size / 2,
                        y: particle.y - particle.size / 2,
                        width: particle.size,
                        height: particle.size
                    )
                    
                    let baseOpacity = particle.opacity * fadeIn
                    let particleColor = colorScheme == .dark
                        ? Color.white.opacity(baseOpacity * 0.8)
                        : Color.appTextPrimary.opacity(baseOpacity * 0.6)
                    
                    context.fill(Path(ellipseIn: rect), with: .color(particleColor))
                    
                    // Glow in dark mode
                    if colorScheme == .dark {
                        let glowRect = rect.insetBy(dx: -2, dy: -2)
                        context.fill(
                            Path(ellipseIn: glowRect),
                            with: .color(Color.appAccent.opacity(baseOpacity * 0.2 * pulseIntensity))
                        )
                    }
                }
            }
            .onAppear {
                screenSize = geometry.size
            }
            .onReceive(timer) { _ in
                // Update pulse phase for animations
                pulsePhase += 0.016
                
                // Calculate target particle count based on progress
                let targetCount = Int(5 + (progress / 100) * 75) // 5 → 80 particles
                
                // Add new particles as progress increases
                if particles.count < targetCount {
                    let currentTime = Date().timeIntervalSinceReferenceDate
                    let newParticle = GrowingNeuron(
                        x: CGFloat.random(in: 0...screenSize.width),
                        y: CGFloat.random(in: 0...screenSize.height),
                        vx: CGFloat.random(in: -0.3...0.3),
                        vy: CGFloat.random(in: -0.3...0.3),
                        size: CGFloat.random(in: 4...7),
                        opacity: Double.random(in: 0.6...0.9),
                        birthTime: currentTime
                    )
                    particles.append(newParticle)
                }
                
                // Update existing particles
                let currentTime = Date().timeIntervalSinceReferenceDate
                for i in particles.indices {
                    particles[i].update(size: screenSize, time: currentTime)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Growing Neuron Model
struct GrowingNeuron {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    let size: CGFloat
    let opacity: Double
    let birthTime: TimeInterval
    
    mutating func update(size: CGSize, time: TimeInterval) {
        let wave = sin(time * 0.3 + x * 0.008) * 0.2
        
        x += vx + wave
        y += vy
        
        // Wrap around edges
        if x < -10 { x = size.width + 10 }
        if x > size.width + 10 { x = -10 }
        if y < -10 { y = size.height + 10 }
        if y > size.height + 10 { y = -10 }
    }
}

// MARK: - Preview
#Preview {
    ProfileSetupAnimationView(isComplete: .constant(false))
}
