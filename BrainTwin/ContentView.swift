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
                // 🔄 Onboarding done but not signed in - show restore screen
                // (This should rarely happen with receipt-based auth)
                RestoreAccountView()

            } else {
                // ✅ Fully onboarded + signed-in via receipt
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

// MARK: - Restore Account View

struct RestoreAccountView: View {
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showError = false
    @State private var errorMessage = ""
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            if colorScheme == .dark {
                RadialGradient(
                    colors: [Color(white: 0.04), .black],
                    center: .center,
                    startRadius: 0,
                    endRadius: 500
                )
                .ignoresSafeArea()
            }
            
            VStack(spacing: 32) {
                Spacer()
                
                // Icon
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.appAccent)
                
                // Title
                VStack(spacing: 12) {
                    Text("Restore Your Account")
                        .font(.title.bold())
                        .foregroundColor(.appTextPrimary)
                    
                    Text("Tap below to restore your subscription and access your account")
                        .font(.body)
                        .foregroundColor(.appTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                
                Spacer()
                
                // Restore Button
                Button {
                    Task {
                        do {
                            try await subscriptionManager.restorePurchases()
                            print("✅ Account restored successfully")
                        } catch {
                            errorMessage = error.localizedDescription
                            showError = true
                        }
                    }
                } label: {
                    HStack {
                        if subscriptionManager.isRestoring {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .black : .white))
                        } else {
                            Image(systemName: "arrow.clockwise")
                            Text("Restore Purchases")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.appAccent)
                    .foregroundColor(colorScheme == .dark ? .black : .white)
                    .cornerRadius(12)
                    .shadow(color: Color.appAccent.opacity(0.3), radius: 8)
                }
                .disabled(subscriptionManager.isRestoring)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .alert("Restore Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
}
