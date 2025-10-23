import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: Home (Dashboard + Brain Hack)
            DashboardView()
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
                InsightsView()  // Changed from InsightsPlaceholderView()
            }
            .tabItem {
                Image(systemName: "bolt.fill")  // Changed from "chart.line.uptrend.xyaxis"
                Text("Streaks")  // Changed from "Insights"
            }
            .tag(2)
            
            // Tab 4: Settings (for future)
            NavigationStack {
                AccountView()
            }
            .tabItem {
                Image(systemName: "person.circle.fill")
                Text("Account")
            }
            .tag(3)
        }
        .tint(.blue) // Active tab color
    }
}

// MARK: - Placeholder Views (for future features)

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
