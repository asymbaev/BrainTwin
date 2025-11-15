import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false  // ✅ FIXED: Now uses @AppStorage
    
//    @State private var isCheckingOnboarding = false
//    @State private var showAnimation = true
    @State private var showAnimation = true


    var body: some View {
        Group {
            if supabase.isInitializing {
                loadingView

            } else if showAnimation {
                NeuralNetworkAnimationView {
                    showAnimation = false
                }

            } else if !hasSeenIntro {
                NeuroTwinIntroView {
                    hasSeenIntro = true
                }

            } else if !hasCompletedOnboarding {
                // 📋 User has not finished onboarding + paywall yet
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)

            } else if !supabase.isSignedIn {
                // 🔐 Onboarding done, NOW ask user to sign in
                SignInView {
                    // when Supabase finishes sign-in, supabase.isSignedIn becomes true
                    // and ContentView will automatically switch to MainTabView
                }

            } else {
                // ✅ Fully onboarded + signed-in
                MainTabView()
            }
        }

//        .task {
//            // ✅ Check onboarding status when signed in
//            if supabase.isSignedIn {
//                await handleSignedIn()
//            }
//        }
//        .onChange(of: supabase.isSignedIn) { signedIn in
//            if signedIn {
//                Task { await handleSignedIn() }
//            } else {
//                // User signed out - reset onboarding status
//                hasCompletedOnboarding = false
//            }
//        }
    }
    
    private var loadingView: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ProgressView()
                .tint(.appAccent)
        }
    }


//    private func handleSignedIn() async {
//        print("🔄 Checking onboarding status from database...")
//        isCheckingOnboarding = true
//        
//        let completedInDB = await supabase.hasCompletedOnboarding()
//        
//        // ✅ Sync local storage with database
//        hasCompletedOnboarding = completedInDB
//        
//        print("✅ Onboarding status: \(completedInDB)")
//        isCheckingOnboarding = false
//    }
}
