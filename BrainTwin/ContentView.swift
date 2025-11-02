import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared
    
    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    @State private var isCheckingOnboarding = false
    @State private var errorText: String?
    
    var body: some View {
        Group {
            // 1) Show intro first
            if !hasSeenIntro {
                NeuroTwinIntroView {
                    hasSeenIntro = true
                    Task { await signInAndCheckOnboarding() }
                }
            
            // 2) Checking onboarding status from database
            } else if isCheckingOnboarding {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    Text("Loading your profile...")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            
            // 3) Signed-in routing based on onboarding status
            } else if supabase.isSignedIn {
                if hasCompletedOnboarding {
                    MainTabView()
                } else {
                    // Onboarding internally shows ProfileSetupAnimationView
                    OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)
                }
            
            // 4) Silent sign-in screen (fallback)
            } else {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    if let error = errorText {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .task { await signInAndCheckOnboarding() }
            }
        }
    }
    
    // MARK: - Sign In & Check Onboarding Status
    
    /// Signs in user and checks onboarding_completed flag from Supabase
    private func signInAndCheckOnboarding() async {
        await MainActor.run {
            isCheckingOnboarding = true
            errorText = nil
        }
        
        do {
            // Step 1: Sign in if needed
            if !supabase.isSignedIn {
                print("🔐 Signing in anonymously...")
                try await supabase.signInAnonymously()
            }
            
            // Step 2: Check onboarding status from Supabase database
            guard let userId = supabase.userId else {
                throw NSError(domain: "ContentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "No user ID after sign in"])
            }
            
            print("📊 Fetching onboarding status from database...")
            let profile: UserProfile = try await supabase.client
                .from("profiles")
                .select("id, onboarding_completed")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // Step 3: Sync database flag with local storage
            await MainActor.run {
                hasCompletedOnboarding = profile.onboarding_completed
                print("✅ Onboarding status synced from database: \(profile.onboarding_completed)")
            }
            
        } catch {
            print("❌ Error checking onboarding: \(error)")
            await MainActor.run {
                errorText = error.localizedDescription
                // Keep current local onboarding status as fallback
            }
        }
        
        await MainActor.run {
            isCheckingOnboarding = false
        }
    }
}

// MARK: - Helper Model

struct UserProfile: Codable {
    let id: String
    let onboarding_completed: Bool
}

#Preview { ContentView() }
