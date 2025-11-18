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
                // 🔄 Onboarding done but not signed in
                // Auto-restore should handle this, but show onboarding again as fallback
                OnboardingView(isOnboardingComplete: $hasCompletedOnboarding)

            } else {
                // ✅ Fully onboarded + signed-in via receipt
                MainTabView()
            }
        }
        // 🧪 DEBUG: Shake device to reset (remove before production)
        .onShake {
            print("🧪 DEBUG: Resetting app state...")
            UserDefaults.standard.removeObject(forKey: "hasSeenIntro_v2")
            UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "justCompletedOnboarding")
            UserDefaults.standard.removeObject(forKey: "pendingOnboardingData")
            exit(0)
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
