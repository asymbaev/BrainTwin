import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false  // ✅ FIXED: Now uses @AppStorage
    
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
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
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
    
    private var loadingView: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
        }
    }

    private func handleSignedIn() async {
        print("🔄 Checking onboarding status from database...")
        isCheckingOnboarding = true
        
        let completedInDB = await supabase.hasCompletedOnboarding()
        
        // ✅ Sync local storage with database
        hasCompletedOnboarding = completedInDB
        
        print("✅ Onboarding status: \(completedInDB)")
        isCheckingOnboarding = false
    }
}
