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

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var isSubscribed: Bool = false
    @Published var isCheckingStatus: Bool = false
    
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
}
