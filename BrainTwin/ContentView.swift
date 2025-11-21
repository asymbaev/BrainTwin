import SwiftUI
import Supabase

struct ContentView: View {
    @StateObject private var supabase = SupabaseManager.shared

    @AppStorage("hasSeenIntro_v2") private var hasSeenIntro = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenThankYou") private var hasSeenThankYou = false  // ✅ NEW: Track thank you screen
    
    @State private var showAnimation = true
    @State private var isCheckingReceipt = true  // ✅ NEW: Wait for receipt check


    var body: some View {
        Group {
            if supabase.isInitializing || isCheckingReceipt {
                // ✅ Show loading while initializing OR checking receipt
                loadingView

            } else if supabase.isSignedIn && hasCompletedOnboarding {
                // ✅ PRIORITY CHECK: User is signed in and has completed onboarding
                
                // Check if this is a NEW user who just completed onboarding
                let justCompleted = UserDefaults.standard.bool(forKey: "justCompletedOnboarding")
                
                if justCompleted && !hasSeenThankYou {
                    // 🎉 NEW USER: Show Thank You screen after purchase
                    ThankYouView {
                        hasSeenThankYou = true
                        UserDefaults.standard.set(false, forKey: "justCompletedOnboarding")
                    }
                    .transition(.opacity)
                    
                } else if showAnimation {
                    // RETURNING USER: Show animation, then MainTabView
                    NeuralNetworkAnimationView {
                        showAnimation = false
                    }
                } else {
                    // Show main app
                    MainTabView()
                }
                
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
                // 🔄 This should NEVER happen now (receipt auto-restore should handle it)
                // But keep as safety fallback
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)

            } else {
                // ✅ Fully onboarded + signed-in via receipt
                MainTabView()
            }
        }
        .task {
            // ✅ CRITICAL: Check receipt BEFORE showing any screens
            await performReceiptCheck()
        }
        // 🧪 DEBUG: Shake device to reset (remove before production)
        .onShake {
            print("🧪 DEBUG: Resetting app state...")
            UserDefaults.standard.removeObject(forKey: "hasSeenIntro_v2")
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "justCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "hasSeenThankYou")
            UserDefaults.standard.removeObject(forKey: "pendingOnboardingData")
            UserDefaults.standard.removeObject(forKey: "lastCheckInDate")
            UserDefaults.standard.removeObject(forKey: "lastHackCompletionDate")
            exit(0)
        }
    }
    
    // ✅ CRITICAL: Perform receipt check on EVERY app launch
    // This handles both force-quit/reopen AND delete/reinstall scenarios
    private func performReceiptCheck() async {
        print("🔍 Checking for existing receipt on app launch...")
        print("   Current state: hasCompletedOnboarding=\(hasCompletedOnboarding), isSignedIn=\(supabase.isSignedIn)")
        
        // ✅ ALWAYS check for receipt (even on fresh install)
        // User might have deleted/reinstalled app but still has valid receipt
        await SubscriptionManager.shared.autoIdentifyFromReceiptIfNeeded()
        
        // ✅ NEW: Pre-fetch data for returning users (during animation time)
        // This eliminates loading states when MainTabView appears
        if supabase.isSignedIn && hasCompletedOnboarding {
            print("🚀 User is returning - pre-fetching data during animation...")
            await prefetchDataForReturningUser()
        }
        
        // Small delay to ensure state updates propagate
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("✅ Receipt check complete")
        print("   Final state: isSignedIn=\(supabase.isSignedIn), hasCompletedOnboarding=\(hasCompletedOnboarding)")
        
        isCheckingReceipt = false
    }
    
    // ✅ NEW: Pre-fetch data while animation plays (parallel loading)
    // This is what Instagram, TikTok, Spotify do - load during transitions!
    private func prefetchDataForReturningUser() async {
        print("📦 [Pre-fetch] Starting parallel data loading during animation...")
        
        // MeterDataManager now fetches BOTH meter data AND complete hack data in parallel
        // This single call loads everything we need for the dashboard
        await MeterDataManager.shared.fetchMeterData(force: false)
        
        print("🎉 [Pre-fetch] All data pre-loaded! MainTabView will render instantly.")
        print("   ✓ Meter data: \(MeterDataManager.shared.meterData != nil ? "ready" : "failed")")
        print("   ✓ Today's hack: \(MeterDataManager.shared.todaysHack != nil ? "ready" : "failed")")
    }
    
    private var loadingView: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            ProgressView()
                .tint(.appAccent)
        }
    }
}


// MARK: - Shake Gesture (Debug Only)

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.modifier(DeviceShakeViewModifier(action: action))
    }
}

struct DeviceShakeViewModifier: ViewModifier {
    let action: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.deviceDidShakeNotification)) { _ in
                action()
            }
    }
}

extension UIDevice {
    static let deviceDidShakeNotification = Notification.Name(rawValue: "deviceDidShakeNotification")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            NotificationCenter.default.post(name: UIDevice.deviceDidShakeNotification, object: nil)
        }
    }
}
