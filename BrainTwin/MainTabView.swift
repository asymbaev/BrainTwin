import SwiftUI
import Supabase

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCheckIn: Bool
    @State private var showRoadmap = false
    @State private var completedCount = 0
    @StateObject private var hackViewModel = DailyHackViewModel()
    @AppStorage("lastCheckInDate") private var lastCheckInDate = ""
    
    // Reference the shared singleton directly
    private let meterDataManager = MeterDataManager.shared
    
    // ⚠️ DEBUG MODE: Set to false for production (once per day behavior)
    // ⚠️ Set to true for testing (always shows check-in flow)
    private let isTestMode = false  // ← CHANGE THIS TO false BEFORE RELEASE
    
    init() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        
        let lastDate = UserDefaults.standard.string(forKey: "lastCheckInDate") ?? ""
        
        // ✅ Check if this is first launch after onboarding
        let justCompletedOnboarding = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
        
        // ✅ Clear the flag immediately
        if justCompletedOnboarding {
            UserDefaults.standard.set(false, forKey: "justCompletedOnboarding")
        }
        
        // In test mode: ALWAYS show check-in
        // In production: Only show if new day AND NOT first launch
        let shouldShow = isTestMode || (!justCompletedOnboarding && lastDate != today)
        
        _showCheckIn = State(initialValue: shouldShow)
        
        if isTestMode {
            print("⚠️ TEST MODE: Check-in will show every time")
        } else if justCompletedOnboarding {
            print("✅ First launch after onboarding - skipping check-in")
        } else {
            print("📅 Returning user - check-in: \(shouldShow)")
        }
    }
    
    var body: some View {
        Group {
            // CONDITIONAL RENDERING: Show only ONE screen at a time
            if showCheckIn {
                // SCREEN 1: Daily Check-In
                DailyCheckInView(onContinue: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCheckIn = false
                        showRoadmap = true
                    }
                })
                .transition(.move(edge: .bottom))
                
            } else if showRoadmap {
                // SCREEN 2: Roadmap
                RoadmapView(completedCount: completedCount) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRoadmap = false
                        
                        // Only save date in production mode
                        if !isTestMode {
                            lastCheckInDate = getTodayString()
                        }
                    }
                }
                .transition(.move(edge: .bottom))
                
            } else {
                // SCREEN 3: Main App (TabView with Dashboard)
                TabView(selection: $selectedTab) {
                    // Tab 1: Home (Dashboard + Brain Hack)
                    DashboardView()
                        .environmentObject(meterDataManager)  // ← NEW: Inject preloaded data
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    // Tab 2: Chat with Brain Twin
                    NavigationStack {
                        ChatView()
                    }
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .tag(1)
                    
                    // Tab 3: Insights (for future)
                    NavigationStack {
                        InsightsView()
                            .environmentObject(meterDataManager)  // ← NEW: Inject preloaded data
                    }
                    .tabItem {
                        Image(systemName: "bolt.fill")
                        Text("Streaks")
                    }
                    .tag(2)
                    
                    // Tab 4: Account - Shows as full page
                    NavigationStack {
                        AccountView()
                    }
                    .tabItem {
                        Image(systemName: "person.circle.fill")
                        Text("Account")
                    }
                    .tag(3)
                }
                .tint(.blue)
                .transition(.opacity)
            }
        }
        .task {
            // ✨ PRELOAD METER DATA IMMEDIATELY (while user is on check-in screen)
            print("🚀 Preloading meter data on check-in screen...")
            await meterDataManager.fetchMeterData()
            
            // START HACK GENERATION IMMEDIATELY (in background)
            Task {
                await hackViewModel.loadTodaysHack()
            }
            
            // Fetch completed count (for roadmap)
            await fetchCompletedCount()
        }
    }
    
    // Get today's date as string (YYYY-MM-DD)
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // Fetch completed count from meter
    private func fetchCompletedCount() async {
        guard let userId = SupabaseManager.shared.userId else { return }
        
        do {
            struct MeterRequest: Encodable {
                let userId: String
            }
            
            let meterResponse: MeterResponse = try await SupabaseManager.shared.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: MeterRequest(userId: userId))
            )
            
            completedCount = meterResponse.completedProtocols
            print("✅ Completed count: \(completedCount)")
            
        } catch {
            print("❌ Failed to fetch completed count: \(error)")
        }
    }
}

// MARK: - Placeholder Views (keep the same)

struct InsightsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Insights")
                .font(.title.bold())
            
            Text("Track your progress, view your stats, and see your brain rewiring journey.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 20)
        }
        .navigationTitle("Insights")
    }
}

struct SettingsPlaceholderView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Settings")
                .font(.title.bold())
            
            Text("Customize your experience, manage notifications, and adjust your preferences.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Text("Coming Soon")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.top, 20)
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    MainTabView()
}
