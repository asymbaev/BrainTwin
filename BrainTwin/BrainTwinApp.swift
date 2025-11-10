import SwiftUI
import SuperwallKit

@main
struct BrainTwinApp: App {

    init() {
        // Initialize Superwall
        Superwall.configure(apiKey: "pk_Ned_vvu1JG8DJn_kq2HS5")

        // Set delegate
        Superwall.shared.delegate = PaywallEventDelegate()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Paywall Delegate

class PaywallEventDelegate: SuperwallDelegate {

    /// The placement you use in OnboardingView.showPaywall()
    /// We’ll force the user back into this paywall when they close it without paying.
    private let onboardingPlacement = "onboarding_complete"

    @MainActor
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {

        // 🔒 User closed or declined the paywall
        case .paywallClose(_),
             .paywallDecline(_):
            let status = Superwall.shared.subscriptionStatus

            switch status {
            case .active:
                // User is subscribed → allow them to continue
                print("💳 Paywall closed with ACTIVE subscription. Letting user through.")

            case .inactive, .unknown:
                // User is NOT subscribed → immediately show the paywall again
                print("⛔️ Paywall closed WITHOUT subscription. Re-opening paywall…")
                Superwall.shared.register(placement: onboardingPlacement)

            @unknown default:
                // Be defensive: treat unknown as not-subscribed
                print("⚠️ Unknown subscription status on paywall close. Re-opening paywall…")
                Superwall.shared.register(placement: onboardingPlacement)
            }

        // ✅ Successful purchase
        case .transactionComplete:
            print("✅ Purchase completed!")
            Task {
                await SubscriptionManager.shared.refreshSubscription()
            }

        // ♻️ Restored purchase
        case .transactionRestore:
            print("♻️ Purchase restored!")
            Task {
                await SubscriptionManager.shared.refreshSubscription()
            }

        default:
            break
        }
    }

    /// Keep SubscriptionManager in sync if Superwall changes status internally
    @MainActor
    func subscriptionStatusDidChange(
        from oldValue: SubscriptionStatus,
        to newValue: SubscriptionStatus
    ) {
        print("🔁 subscriptionStatusDidChange: \(oldValue) → \(newValue)")
        Task {
            await SubscriptionManager.shared.checkSubscriptionStatus()
        }
    }
}
