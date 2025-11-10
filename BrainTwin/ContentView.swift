import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @State private var hasCompletedOnboarding = false  // ✅ CHANGED from @AppStorage to @State
    
    @State private var isCheckingOnboarding = false
    @State private var showAnimation = true

    var body: some View {
        Group {
            // ⏳ INITIALIZING (checking for session)
            if supabase.isInitializing {
                loadingView
                
            } else if showAnimation {
                // ⚡ OPENING ANIMATION
                NeuralNetworkAnimationView {
                    showAnimation = false
                }
                
            } else if !hasSeenIntro {
                // 📱 INTRO SCREEN
                NeuroTwinIntroView {
                    hasSeenIntro = true
                }

            } else if !supabase.isSignedIn {
                // 🔐 SIGN-IN
                SignInView {
                    Task { await handleSignedIn() }
                }

            } else if isCheckingOnboarding {
                // ⏳ CHECKING ONBOARDING STATUS
                loadingView

            } else if hasCompletedOnboarding {
                // ✅ DASHBOARD
                MainTabView()

            } else {
                // 📋 ONBOARDING
                OnboardingView(isOnboardingComplete: Binding(
                    get: { hasCompletedOnboarding },
                    set: { newValue in
                        hasCompletedOnboarding = newValue
                        // ✅ Save to @AppStorage when completed
                        if newValue {
                            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                        }
                    }
                ))
            }
        }
        .task {
            // ✅ Check onboarding status when signed in
            if supabase.isSignedIn {
                await handleSignedIn()
            }
        }
        .onChange(of: supabase.isSignedIn) { signedIn in
            if signedIn {
                Task { await handleSignedIn() }
            } else {
                // User signed out - reset onboarding status
                hasCompletedOnboarding = false
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    /// Check database for onboarding status and sync with local state
    private func handleSignedIn() async {
        print("🔄 Checking onboarding status from database...")
        
        await MainActor.run { isCheckingOnboarding = true }
        
        // ✅ Fetch from DATABASE (source of truth)
        let completedInDatabase = await supabase.hasCompletedOnboarding()
        
        await MainActor.run {
            hasCompletedOnboarding = completedInDatabase
            isCheckingOnboarding = false
            
            // ✅ Sync local storage with database
            UserDefaults.standard.set(completedInDatabase, forKey: "hasCompletedOnboarding")
            
            print("✅ Onboarding status: \(completedInDatabase)")
        }
    }
}

#Preview { ContentView() }
