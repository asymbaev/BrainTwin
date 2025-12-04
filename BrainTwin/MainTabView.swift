import SwiftUI
import Supabase
import Functions

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showCheckIn = false
    @State private var showRoadmap = false
    @State private var completedCount = 0
    @State private var isCheckingConditions: Bool
    @StateObject private var hackViewModel = DailyHackViewModel()
    @AppStorage("lastCheckInDate") private var lastCheckInDate = ""
    @AppStorage("lastHackCompletionDate") private var lastHackCompletionDate = ""
    
    private let meterDataManager = MeterDataManager.shared
    private let isTestMode = false
    
    init() {
        let justCompletedOnboarding = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
        
        if justCompletedOnboarding {
            _isCheckingConditions = State(initialValue: false)
            print("✅ [MainTabView Init] Fresh user detected - skipping check-in checks")
        } else {
            _isCheckingConditions = State(initialValue: true)
            print("📱 [MainTabView Init] Returning user - will check conditions")
        }
        
        // Custom tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.appBackground)
        
        // Remove default styling
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.appTextSecondary)
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.appTextSecondary)]
        
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.appAccent)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor(Color.appAccent)]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        Group {
            if isCheckingConditions {
                Color.appBackground.ignoresSafeArea()
                
            } else if showCheckIn {
                DailyCheckInView(onContinue: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showCheckIn = false
                        showRoadmap = true
                    }
                })
                .transition(.move(edge: .bottom))
                
            } else if showRoadmap {
                RoadmapView(completedCount: completedCount) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showRoadmap = false
                        
                        if !isTestMode {
                            lastCheckInDate = getTodayString()
                            print("✅ Check-in complete - saved date: \(lastCheckInDate)")
                        }
                    }
                }
                .transition(.move(edge: .bottom))
                
            } else {
                // Main App (TabView with Dashboard)
                TabView(selection: $selectedTab) {
                    // Tab 1: Home (Dashboard + Brain Hack)
                    DashboardView()
                        .environmentObject(meterDataManager)
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(0)
                    
                    // Tab 2: Chat with NeuroChat
                    NavigationStack {
                        ChatView()
                    }
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .tag(1)
                    
                    // Tab 3: Streaks
                    NavigationStack {
                        InsightsView()
                            .environmentObject(meterDataManager)
                    }
                    .tabItem {
                        Image(systemName: "flame.fill")
                        Text("Streaks")
                    }
                    .tag(2)
                }
                .tint(.appAccent)
                .transition(.opacity)
            }
        }
        .task {
            print("📱 MainTabView loaded - checking cache...")
            await meterDataManager.fetchMeterData()
            await determineCheckInFlow()
            
            Task {
                await hackViewModel.loadTodaysHack()
            }
            
            await fetchCompletedCount()
        }
    }
    
    private func determineCheckInFlow() async {
        let today = getTodayString()
        
        print("🔍 [Check-In Logic] Checking conditions...")
        print("   Today: \(today)")
        print("   Last check-in: \(lastCheckInDate)")
        print("   Last hack completion: \(lastHackCompletionDate)")
        
        let justCompletedOnboarding = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
        
        if justCompletedOnboarding {
            UserDefaults.standard.set(false, forKey: "justCompletedOnboarding")
            lastCheckInDate = today
            print("✅ [Check-In Logic] First launch after onboarding - skipping check-in")
            isCheckingConditions = false
            return
        }
        
        if meterDataManager.isTodayHackComplete {
            print("❌ [Check-In Logic] Today's hack already completed - skipping check-in (reinstall scenario)")
            lastCheckInDate = today
            isCheckingConditions = false
            return
        }
        
        if isTestMode {
            print("⚠️ [Check-In Logic] TEST MODE - showing check-in")
            showCheckIn = true
            isCheckingConditions = false
            return
        }
        
        guard lastCheckInDate != today else {
            print("❌ [Check-In Logic] Already checked in today")
            isCheckingConditions = false
            return
        }
        
        let yesterday = getYesterdayString()
        let completedYesterday = (lastHackCompletionDate == yesterday)
        let hasActiveStreak = (meterDataManager.meterData?.streak ?? 0) > 0
        
        print("   Yesterday: \(yesterday)")
        print("   Completed yesterday: \(completedYesterday)")
        print("   Active streak: \(hasActiveStreak)")
        
        if completedYesterday || hasActiveStreak {
            print("✅ [Check-In Logic] Conditions met - showing check-in flow")
            showCheckIn = true
        } else {
            print("❌ [Check-In Logic] User didn't complete yesterday's hack - skipping check-in")
            lastCheckInDate = today
        }
        
        isCheckingConditions = false
    }
    
    private func getTodayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
    
    private func getYesterdayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return formatter.string(from: yesterday)
    }
    
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

#Preview {
    MainTabView()
}
