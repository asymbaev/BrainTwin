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

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed: Bool = false
    @Published var isCheckingStatus: Bool = false
    @Published var isRestoring: Bool = false
    
    // Product IDs
    private let productIds = ["braintwin_weekly_299", "braintwin_monthly_999", "braintwin_yearly_2999"]
    
    private init() {
        // Check status on init
        Task {
            await checkSubscriptionStatus()
        }
    }
    
    /// Check if user has active subscription
    func checkSubscriptionStatus() async {
        isCheckingStatus = true
        
        // Check with Superwall
        let status = Superwall.shared.subscriptionStatus
        
        switch status {
        case .active:
            isSubscribed = true
            await saveSubscriptionToDatabase(isActive: true)
            print("✅ User is subscribed")
            
        case .inactive, .unknown:
            isSubscribed = false
            await saveSubscriptionToDatabase(isActive: false)
            print("❌ User is not subscribed")
            
        @unknown default:
            isSubscribed = false
        }
        
        isCheckingStatus = false
    }
    
    /// Save subscription status to Supabase
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
    
    /// Force refresh subscription status
    func refreshSubscription() async {
        await checkSubscriptionStatus()
    }
    
    // MARK: - Receipt-Based User Creation
    
    /// Creates user from receipt after purchase (called by PaywallEventDelegate)
    func createUserFromReceiptAfterPurchase() async throws {
        print("📱 Creating user account from receipt...")
        
        // Get pending onboarding data
        guard let onboardingData = getPendingOnboardingData() else {
            throw NSError(
                domain: "SubscriptionManager",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "No pending onboarding data found"]
            )
        }
        
        // Get original transaction ID from StoreKit
        guard let originalTransactionId = try await getCurrentOriginalTransactionId() else {
            throw NSError(
                domain: "SubscriptionManager",
                code: -2,
                userInfo: [NSLocalizedDescriptionKey: "Could not get transaction ID from receipt"]
            )
        }
        
        // Call Edge Function to create user
        let userId = try await SupabaseManager.shared.createOrIdentifyUserFromReceipt(
            originalTransactionId: originalTransactionId,
            onboardingData: onboardingData
        )
        
        // Clear pending data
        UserDefaults.standard.removeObject(forKey: "pendingOnboardingData")
        
        print("✅ User account created successfully from receipt. User ID: \(userId)")
    }
    
    // MARK: - Restore Purchases
    
    /// Restores purchases and user account from receipt
    func restorePurchases() async throws {
        print("🔄 Starting restore purchases...")
        isRestoring = true
        
        defer {
            Task { @MainActor in
                self.isRestoring = false
            }
        }
        
        // Sync with StoreKit
        try await AppStore.sync()
        
        // Get original transaction ID
        guard let originalTransactionId = try await getCurrentOriginalTransactionId() else {
            throw NSError(
                domain: "SubscriptionManager",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "No valid subscription found to restore"]
            )
        }
        
        // Restore user from receipt
        let userId = try await SupabaseManager.shared.restoreUserFromReceipt(
            originalTransactionId: originalTransactionId
        )
        
        // Refresh subscription status
        await checkSubscriptionStatus()
        
        print("✅ Purchases restored successfully. User ID: \(userId)")
    }
    
    // MARK: - Helper Methods
    
    /// Gets pending onboarding data from UserDefaults
    private func getPendingOnboardingData() -> OnboardingData? {
        guard let data = UserDefaults.standard.data(forKey: "pendingOnboardingData") else {
            print("⚠️ No pending onboarding data found")
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
    
    /// Gets the current original transaction ID from StoreKit
    private func getCurrentOriginalTransactionId() async throws -> String? {
        // Check for current entitlements for all product IDs
        for productId in productIds {
            if let verificationResult = await Transaction.currentEntitlement(for: productId) {
                // Unwrap the verification result to get the actual transaction
                switch verificationResult {
                case .verified(let transaction):
                    let originalId = String(transaction.originalID)
                    print("✅ Found verified transaction for \(productId): \(originalId)")
                    return originalId
                case .unverified(let transaction, let verificationError):
                    print("⚠️ Found unverified transaction for \(productId): \(verificationError)")
                    // Still return the transaction ID even if unverified (for development/testing)
                    let originalId = String(transaction.originalID)
                    return originalId
                }
            }
        }
        
        print("⚠️ No current entitlements found for any product")
        return nil
    }
}
