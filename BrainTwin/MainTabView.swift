import SwiftUI
import Supabase

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCheckIn = false
    @State private var showRoadmap = false
    @State private var completedCount = 0
    @State private var isCheckingConditions: Bool
    @StateObject private var hackViewModel = DailyHackViewModel()
    @AppStorage("lastCheckInDate") private var lastCheckInDate = ""
    @AppStorage("lastHackCompletionDate") private var lastHackCompletionDate = ""
    
    // Reference the shared singleton directly
    private let meterDataManager = MeterDataManager.shared
    
    // ⚠️ DEBUG MODE: Set to false for production (once per day behavior)
    // ⚠️ Set to true for testing (always shows check-in flow)
    private let isTestMode = false  // ← CHANGE THIS TO false BEFORE RELEASE
    
    // ✅ OPTION 1 FIX: Skip loading for fresh users
    init() {
        let justCompletedOnboarding = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
        
        if justCompletedOnboarding {
            // Fresh user after onboarding - skip check-in logic, go straight to dashboard
            _isCheckingConditions = State(initialValue: false)
            print("✅ [MainTabView Init] Fresh user detected - skipping check-in checks")
        } else {
            // Returning user - need to check conditions
            _isCheckingConditions = State(initialValue: true)
            print("📱 [MainTabView Init] Returning user - will check conditions")
        }
    }
    
    var body: some View {
        Group {
            // CONDITIONAL RENDERING: Show only ONE screen at a time
            if isCheckingConditions {
                // LOADING: Checking if we should show check-in
                Color.appBackground.ignoresSafeArea()
                
            } else if showCheckIn {
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
                            print("✅ Check-in complete - saved date: \(lastCheckInDate)")
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
            // ✅ STEP 1: Ensure data is loaded (should be cached from animation)
            print("📱 MainTabView loaded - checking cache...")
            await meterDataManager.fetchMeterData()

            // ✅ STEP 2: Determine if check-in should show
            await determineCheckInFlow()

            // ✅ STEP 3: Load hack data (will use cache if available)
            Task {
                await hackViewModel.loadTodaysHack()
            }

            // ✅ STEP 4: Fetch completed count for roadmap
            await fetchCompletedCount()
        }
    }
    
    // ✅ NEW: Determine if check-in flow should show
    private func determineCheckInFlow() async {
        let today = getTodayString()
        
        print("🔍 [Check-In Logic] Checking conditions...")
        print("   Today: \(today)")
        print("   Last check-in: \(lastCheckInDate)")
        print("   Last hack completion: \(lastHackCompletionDate)")
        
        // ✅ Check if this is first launch after onboarding
        let justCompletedOnboarding = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
        
        if justCompletedOnboarding {
            // First launch - skip check-in, save today's date
            UserDefaults.standard.set(false, forKey: "justCompletedOnboarding")
            lastCheckInDate = today
            print("✅ [Check-In Logic] First launch after onboarding - skipping check-in")
            isCheckingConditions = false
            return
        }
        
        // ✅ NEW: Check if today's hack is already completed (prevents check-in after reinstall on same day)
        if meterDataManager.isTodayHackComplete {
            print("❌ [Check-In Logic] Today's hack already completed - skipping check-in (reinstall scenario)")
            lastCheckInDate = today  // Sync local cache with backend truth
            isCheckingConditions = false
            return
        }
        
        // ✅ TEST MODE: Always show check-in
        if isTestMode {
            print("⚠️ [Check-In Logic] TEST MODE - showing check-in")
            showCheckIn = true
            isCheckingConditions = false
            return
        }
        
        // ✅ Check if it's a new day
        guard lastCheckInDate != today else {
            print("❌ [Check-In Logic] Already checked in today")
            isCheckingConditions = false
            return
        }
        
        // ✅ NEW DAY: Check if user completed yesterday's hack
        let yesterday = getYesterdayString()
        let completedYesterday = (lastHackCompletionDate == yesterday)
        
        // Alternative check: Use streak data (if available)
        let hasActiveStreak = (meterDataManager.meterData?.streak ?? 0) > 0
        
        print("   Yesterday: \(yesterday)")
        print("   Completed yesterday: \(completedYesterday)")
        print("   Active streak: \(hasActiveStreak)")
        
        // ✅ SHOW CHECK-IN IF: User completed yesterday's hack
        if completedYesterday || hasActiveStreak {
            print("✅ [Check-In Logic] Conditions met - showing check-in flow")
            showCheckIn = true
        } else {
            print("❌ [Check-In Logic] User didn't complete yesterday's hack - skipping check-in")
            // Save today's date so we don't check again today
            lastCheckInDate = today
        }
        
        isCheckingConditions = false
    }
    
    // Get today's date as string (YYYY-MM-DD)
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    // ✅ NEW: Get yesterday's date as string (YYYY-MM-DD)
    private func getYesterdayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.string(from: yesterday)
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
