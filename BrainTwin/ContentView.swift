import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @State private var isCheckingOnboarding = false
    @State private var showAnimation = true // Always starts true

    var body: some View {
        Group {
            if showAnimation {
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
                // ⏳ LOADING
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
            if supabase.isSignedIn && !hasCompletedOnboarding {
                await handleSignedIn()
            }
        }
        .onChange(of: supabase.isSignedIn) { signedIn in
            if signedIn {
                Task { await handleSignedIn() }
            }
        }
    }

    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading your profile...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
    }

    private func handleSignedIn() async {
        await MainActor.run { isCheckingOnboarding = true }
        let completed = await supabase.hasCompletedOnboarding()
        await MainActor.run {
            hasCompletedOnboarding = completed
            isCheckingOnboarding = false
        }
    }
}

#Preview { ContentView() }
