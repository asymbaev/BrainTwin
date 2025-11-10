import SwiftUI
import SuperwallKit
import UserNotifications
import Supabase

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
    /// We'll force the user back into this paywall when they close it without paying.
    private let onboardingPlacement = "onboarding_complete"
    
    /// Track when paywall was first shown for discount timer
    private var paywallShownTime: Date?
    
    /// Timer for showing discount after 5 minutes
    private var discountTimer: Timer?

    @MainActor
    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        switch eventInfo.event {
        
        // 👁️ Paywall was presented
        case .paywallOpen:
            print("👁️ Paywall opened!")
            startDiscountTimer()

        // 🔒 User closed or declined the paywall
        case .paywallClose(_),
             .paywallDecline(_):
            cancelDiscountTimer()
            
            let status = Superwall.shared.subscriptionStatus

            switch status {
            case .active:
                // User is subscribed → allow them to continue
                print("💳 Paywall closed with ACTIVE subscription. Letting user through.")

            case .inactive, .unknown:
                // User is NOT subscribed → schedule notification and track
                print("⛔️ Paywall closed WITHOUT subscription.")
                
                // Schedule discount notification for non-subscribers
                Task {
                    await scheduleDiscountNotification()
                    await trackPaywallNudge(converted: false)
                }
                
                // Re-open paywall
                Superwall.shared.register(placement: onboardingPlacement)

            @unknown default:
                // Be defensive: treat unknown as not-subscribed
                print("⚠️ Unknown subscription status on paywall close. Re-opening paywall…")
                Superwall.shared.register(placement: onboardingPlacement)
            }

        // ✅ Successful purchase
        case .transactionComplete:
            print("✅ Purchase completed!")
            cancelDiscountTimer()
            
            Task {
                await SubscriptionManager.shared.refreshSubscription()
                await trackPaywallNudge(converted: true)
            }

        // ♻️ Restored purchase
        case .transactionRestore:
            print("♻️ Purchase restored!")
            cancelDiscountTimer()
            
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
    
    // MARK: - Discount Timer Logic
    
    /// Start 5-minute timer when paywall opens
    private func startDiscountTimer() {
        paywallShownTime = Date()
        
        // Cancel any existing timer
        cancelDiscountTimer()
        
        print("⏱️ Starting 5-minute discount timer...")
        
        // Schedule timer for 5 minutes (300 seconds)
        discountTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.showDiscountButton()
            }
        }
    }
    
    /// Cancel discount timer if user subscribes or closes paywall early
    private func cancelDiscountTimer() {
        discountTimer?.invalidate()
        discountTimer = nil
        paywallShownTime = nil
        print("⏱️ Discount timer cancelled")
    }
    
    /// Show discount button after 5 minutes
    @MainActor
    private func showDiscountButton() async {
        print("🎁 5 minutes elapsed! Showing discount button...")
        
        // Trigger Superwall "Discount Button" campaign
        Superwall.shared.register(placement: "show_discount_button")
        
        // Track in Supabase
        await trackDiscountShown()
    }
    
    // MARK: - Notification Logic
    
    /// Schedule discount notification 5 minutes after paywall view
    @MainActor
    private func scheduleDiscountNotification() async {
        // Get user's name from Supabase
        guard let userName = await getUserName() else {
            print("❌ Could not get user name for notification")
            return
        }
        
        let center = UNUserNotificationCenter.current()
        
        // Remove any pending discount notifications
        center.removePendingNotificationRequests(withIdentifiers: ["discount_nudge"])
        
        let content = UNMutableNotificationContent()
        content.title = "Hey \(userName) 👋"
        content.body = "You made it this far. You're about to invest in your life - here's 80% off!"
        content.sound = .default
        content.badge = 1
        
        // Trigger 5 minutes from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 300, repeats: false)
        
        let request = UNNotificationRequest(
            identifier: "discount_nudge",
            content: content,
            trigger: trigger
        )
        
        do {
            try await center.add(request)
            print("✅ Discount notification scheduled for 5 minutes from now")
        } catch {
            print("❌ Failed to schedule notification: \(error)")
        }
    }
    
    // MARK: - Supabase Tracking
    
    /// Get user's name from Supabase for personalized notification
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
    
    /// Track when discount is shown to user
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
    
    /// Track paywall outcome (converted or not)
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
