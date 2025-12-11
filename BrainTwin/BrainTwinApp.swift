import SwiftUI
import SuperwallKit
import UserNotifications
import Supabase

@main
struct BrainTwinApp: App {
    private let paywallDelegate = PaywallEventDelegate()

    init() {
        Superwall.configure(apiKey: "pk_Ned_vvu1JG8DJn_kq2HS5")
        Superwall.shared.delegate = paywallDelegate
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Paywall Delegate

class PaywallEventDelegate: SuperwallDelegate {
    private let onboardingPlacement = "onboarding_complete"
    private var paywallShownTime: Date?
    private var discountTimer: Timer?

    @MainActor
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        
        case .paywallOpen:
            print("👁️ Paywall opened!")
            startDiscountTimer()
            // ✅ Hack generation now happens earlier during "Did You Know?" screen in onboarding
            // No need to generate here anymore!

        case .paywallClose(_), .paywallDecline(_):
            cancelDiscountTimer()
            
            let status = Superwall.shared.subscriptionStatus

            switch status {
            case .active:
                print("💳 Paywall closed with ACTIVE subscription. Letting user through.")

            case .inactive, .unknown:
                print("⛔️ Paywall closed WITHOUT subscription.")
                
                Task {
                    await scheduleDiscountNotification()
                    await trackPaywallNudge(converted: false)
                }
                
                Superwall.shared.register(placement: onboardingPlacement)

            @unknown default:
                print("⚠️ Unknown subscription status on paywall close. Re-opening paywall…")
                Superwall.shared.register(placement: onboardingPlacement)
            }

        case .transactionComplete:
            print("✅ Purchase completed!")
            cancelDiscountTimer()

            Task {
                // ✅ Try to identify user, but don't block on failure
                do {
                    try await SubscriptionManager.shared.identifyUserFromReceiptAfterPurchase()
                    print("✅ User identified from receipt")
                } catch {
                    print("❌ Failed to identify user from receipt: \(error)")
                    print("⚠️ Will retry identification from OnboardingView...")
                    // ✅ DON'T RETURN - continue to post notification so OnboardingView can handle retry
                }

                await SubscriptionManager.shared.refreshSubscription()

                // ✅ Hack generation already completed during "Did You Know?" screen
                print("✅ Hack should already be generated from earlier in onboarding!")

                // ✅ ALWAYS post notification, even if initial identification failed
                print("📣 Posting purchase completion notification...")
                NotificationCenter.default.post(name: .purchaseCompleted, object: nil)

                await trackPaywallNudge(converted: true)
            }

        // ✅ REMOVED: transactionRestore case - automatic identification on launch handles this

        default:
            break
        }
    }

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
    
    // MARK: - Discount Timer Logic
    
    private func startDiscountTimer() {
        paywallShownTime = Date()
        cancelDiscountTimer()
        
        print("⏱️ Starting 5-minute discount timer...")
        
        discountTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.showDiscountButton()
            }
        }
    }
    
    private func cancelDiscountTimer() {
        discountTimer?.invalidate()
        discountTimer = nil
        paywallShownTime = nil
        print("⏱️ Discount timer cancelled")
    }
    
    @MainActor
    private func showDiscountButton() async {
        print("🎁 5 minutes elapsed! Showing discount button...")
        Superwall.shared.register(placement: "show_discount_button")
        await trackDiscountShown()
    }
    
    // MARK: - Notification Logic
    
    @MainActor
    private func scheduleDiscountNotification() async {
        guard let userName = await getUserName() else {
            print("❌ Could not get user name for notification")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["discount_nudge"])
        
        let content = UNMutableNotificationContent()
        content.title = "Hey \(userName) 👋"
        content.body = "You made it this far. You're about to invest in your life - here's 80% off!"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        let request = UNNotificationRequest(identifier: "discount_nudge", content: content, trigger: trigger)
        
        do {
            try await center.add(request)
            print("✅ Discount notification scheduled for 5 minutes")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }
    
    @MainActor
    private func getUserName() async -> String? {
        do {
            guard let userId = SupabaseManager.shared.userId else {
                print("❌ No user ID found")
                return nil
            }
            
            let user: SupabaseManager.BrainTwinUser = try await SupabaseManager.shared.client
                .from("users")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            return user.name ?? "there"
        } catch {
            print("❌ Failed to get user name: \(error)")
            return "there"
        }
    }
    
    @MainActor
    private func trackDiscountShown() async {
        do {
            guard let userId = SupabaseManager.shared.userId else {
                print("❌ No user ID for tracking")
                return
            }
            
            struct DiscountEvent: Encodable {
                let user_id: String
                let event_type: String
                let created_at: String
            }
            
            let event = DiscountEvent(
                user_id: userId,
                event_type: "discount_shown",
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await SupabaseManager.shared.client
                .from("paywall_events")
                .insert(event)
                .execute()
            
            print("✅ Tracked: discount_shown event")
            
        } catch {
            print("❌ Failed to track discount shown: \(error)")
        }
    }
    
    @MainActor
    private func trackPaywallNudge(converted: Bool) async {
        do {
            guard let userId = SupabaseManager.shared.userId else {
                print("❌ No user ID for tracking")
                return
            }
            
            struct PaywallNudge: Encodable {
                let user_id: String
                let event_type: String
                let converted: Bool
                let created_at: String
            }
            
            let nudge = PaywallNudge(
                user_id: userId,
                event_type: "paywall_nudge",
                converted: converted,
                created_at: ISO8601DateFormatter().string(from: Date())
            )
            
            try await SupabaseManager.shared.client
                .from("paywall_events")
                .insert(nudge)
                .execute()
            
            print("✅ Tracked: paywall_nudge - converted: \(converted)")
            
        } catch {
            print("❌ Failed to track paywall nudge: \(error)")
        }
    }
}
