//
//  SubscriptionManager.swift
//  BrainTwin
//
//  Created by Dastan Asymbaev on 11/4/25.
//

import Foundation
import SuperwallKit
import Supabase
import Combine
import StoreKit

// MARK: - Notification Names

extension Notification.Name {
    static let purchaseCompleted = Notification.Name("purchaseCompleted")
}

// MARK: - Subscription Manager

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed: Bool = false
    @Published var isCheckingStatus: Bool = false
    
    // Product IDs
    private let productIds = ["braintwin_weekly_299", "braintwin_monthly_999", "braintwin_yearly_2999"]
    
    private init() {
        // Note: Auto-identify is now called from ContentView.performReceiptCheck()
        // to ensure proper timing and state updates
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    /// Check if user has active subscription
    func checkSubscriptionStatus() async {
        isCheckingStatus = true
        
        let status = Superwall.shared.subscriptionStatus
        let hasAccount = SupabaseManager.shared.userId != nil
        
        print("🔍 Checking subscription status: \(status)")
        print("   Has userId: \(hasAccount)")
        
        switch status {
        case .active:
            if hasAccount {
                isSubscribed = true
                await saveSubscriptionToDatabase(isActive: true)
                print("✅ User is subscribed (with account)")
            } else {
                isSubscribed = false
                Superwall.shared.subscriptionStatus = .inactive
                print("⚠️ Superwall had cached ACTIVE status but no account found")
                print("   → Forcing Superwall status to INACTIVE to allow paywall")
            }
            
        case .inactive, .unknown:
            isSubscribed = false
            await saveSubscriptionToDatabase(isActive: false)
            print("❌ User is not subscribed")
            
        @unknown default:
            isSubscribed = false
        }
        
        isCheckingStatus = false
    }
    
    private func saveSubscriptionToDatabase(isActive: Bool) async {
        guard let userId = SupabaseManager.shared.userId else {
            print("⚠️ No user ID to save subscription")
            return
        }
        
        do {
            try await SupabaseManager.shared.client
                .from("users")
                .update(["is_premium": isActive])
                .eq("id", value: userId)
                .execute()
            
            print("✅ Subscription status saved to database: \(isActive)")
        } catch {
            print("❌ Failed to save subscription: \(error)")
        }
    }
    
    func refreshSubscription() async {
        await checkSubscriptionStatus()
    }
    
    // MARK: - Receipt-Based User Identification (UNIFIED)
    
    /// Identifies or creates user from receipt after purchase
    /// Works for BOTH first-time AND returning users automatically
    func identifyUserFromReceiptAfterPurchase() async throws {
        print("📱 Identifying user from receipt after purchase...")

        // Get pending onboarding data (may be nil for returning users)
        let onboardingData = getPendingOnboardingData()

        // Get original transaction ID from StoreKit
        guard let originalTransactionId = try await getCurrentOriginalTransactionId() else {
            throw NSError(
                domain: "SubscriptionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Could not get transaction ID from receipt"]
            )
        }

        // ✅ NEW: If user is already signed in (anonymous), link receipt to existing account
        if SupabaseManager.shared.isSignedIn, let userId = SupabaseManager.shared.userId {
            print("🔗 [Receipt] User already signed in (anonymous), linking receipt to existing account")
            print("   User ID: \(userId)")
            print("   Receipt ID: \(originalTransactionId)")

            try await SupabaseManager.shared.linkReceiptToExistingUser(
                userId: userId,
                originalTransactionId: originalTransactionId,
                onboardingData: onboardingData
            )

            // Clear pending data
            UserDefaults.standard.removeObject(forKey: "pendingOnboardingData")

            print("✅ Receipt linked to existing anonymous user")
            return
        }

        // ✅ Fallback: User not signed in, use receipt to create/identify user
        let result = try await SupabaseManager.shared.identifyUserFromReceipt(
            originalTransactionId: originalTransactionId,
            onboardingData: onboardingData
        )

        // Clear pending data
        UserDefaults.standard.removeObject(forKey: "pendingOnboardingData")

        if result.isNewUser {
            print("✅ New user account created from receipt. User ID: \(result.userId)")
        } else {
            print("✅ Returning user identified from receipt. User ID: \(result.userId)")
        }
    }
    
    // MARK: - Auto-Identify on Launch
    
    /// Automatically identifies user from receipt on app launch
    /// No restrictions - works for ALL users with valid receipts
    /// ✅ CRITICAL: This should be called from ContentView to ensure proper timing
    func autoIdentifyFromReceiptIfNeeded() async {
        print("🔍 [AutoIdentify] Starting auto-identify check...")
        
        // Skip if already signed in
        if SupabaseManager.shared.isSignedIn {
            print("✅ [AutoIdentify] User already signed in, no auto-identify needed")
            print("   User ID: \(SupabaseManager.shared.userId ?? "nil")")
            return
        }
        
        // Check if there's a valid subscription receipt
        guard let originalTransactionId = try? await getCurrentOriginalTransactionId() else {
            print("ℹ️ [AutoIdentify] No subscription receipt found - user is new")
            return
        }
        
        print("🔄 [AutoIdentify] Found subscription receipt, auto-identifying user...")
        print("   Receipt ID: \(originalTransactionId)")
        
        do {
            // Silently identify/restore user from receipt
            let result = try await SupabaseManager.shared.identifyUserFromReceipt(
                originalTransactionId: originalTransactionId,
                onboardingData: nil
            )
            
            // Refresh subscription status
            await checkSubscriptionStatus()
            
            if result.isNewUser {
                print("✅ [AutoIdentify] New user created! User ID: \(result.userId)")
            } else {
                print("✅ [AutoIdentify] Returning user restored! User ID: \(result.userId)")
                
                // ✅ CRITICAL: Mark onboarding as complete for returning users
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                print("   ✓ hasCompletedOnboarding set to TRUE")
            }
            
            // Verify final state
            print("📊 [AutoIdentify] Final state:")
            print("   isSignedIn: \(SupabaseManager.shared.isSignedIn)")
            print("   userId: \(SupabaseManager.shared.userId ?? "nil")")
            print("   isSubscribed: \(isSubscribed)")
            
        } catch {
            print("❌ [AutoIdentify] Failed: \(error.localizedDescription)")
            // Silent failure - user can continue as new user
        }
    }
    
    // MARK: - Helper Methods
    
    private func getPendingOnboardingData() -> OnboardingData? {
        guard let data = UserDefaults.standard.data(forKey: "pendingOnboardingData") else {
            print("ℹ️ No pending onboarding data found (normal for returning users)")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            let onboardingData = try decoder.decode(OnboardingData.self, from: data)
            print("✅ Retrieved pending onboarding data: \(onboardingData.name)")
            return onboardingData
        } catch {
            print("❌ Failed to decode onboarding data: \(error)")
            return nil
        }
    }
    
    private func getCurrentOriginalTransactionId() async throws -> String? {
        // Check for current entitlements for all product IDs
        for productId in productIds {
            if let verificationResult = await Transaction.currentEntitlement(for: productId) {
                switch verificationResult {
                case .verified(let transaction):
                    let originalId = String(transaction.originalID)
                    print("✅ Found verified transaction for \(productId): \(originalId)")
                    return originalId
                case .unverified(let transaction, let verificationError):
                    print("⚠️ Found unverified transaction for \(productId): \(verificationError)")
                    let originalId = String(transaction.originalID)
                    return originalId
                }
            }
        }
        
        print("⚠️ No current entitlements found")
        return nil
    }
}
