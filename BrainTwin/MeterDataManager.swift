import Foundation
import SwiftUI
import Supabase
import Combine

/// Shared manager that preloads and caches meter data
/// This eliminates duplicate API calls and ensures data is ready before user reaches dashboard
@MainActor
final class MeterDataManager: ObservableObject {
    static let shared = MeterDataManager()
    
    @Published var meterData: MeterResponse?
    @Published var isTodayHackComplete = false  // ← NEW: Preload completion status
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastFetchDate: Date?
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches meter data AND today's hack completion status
    /// Call this early (e.g., on check-in screen) to preload data
    func fetchMeterData(force: Bool = false) async {
        guard let userId = supabase.userId else {
            errorMessage = "No user ID found"
            return
        }
        
        // Don't fetch again if we already have recent data (unless forced)
        if !force, let lastFetch = lastFetchDate, Date().timeIntervalSince(lastFetch) < 60 {
            print("📊 Using cached meter data (fetched \(Int(Date().timeIntervalSince(lastFetch)))s ago)")
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        // Fetch both meter data and completion status in parallel
        async let meterTask: () = fetchMeter(userId: userId)
        async let completionTask: () = fetchTodayCompletion(userId: userId)
        
        // Wait for both
        await meterTask
        await completionTask
        
        lastFetchDate = Date()
        isLoading = false
    }
    
    // MARK: - Private Fetch Methods
    
    private func fetchMeter(userId: String) async {
        do {
            struct MeterRequest: Encodable {
                let userId: String
            }
            
            let response: MeterResponse = try await supabase.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: MeterRequest(userId: userId))
            )
            
            meterData = response
            print("✅ Meter data preloaded: \(response.progress)% progress, \(response.streak) day streak")
            
        } catch {
            errorMessage = "Failed to load meter data: \(error.localizedDescription)"
            print("❌ Meter fetch error: \(error)")
        }
    }
    
    private func fetchTodayCompletion(userId: String) async {
        do {
            struct HackRequest: Encodable { let userId: String }
            struct HackResponse: Decodable { let isCompleted: Bool? }
            
            let response: HackResponse = try await supabase.client.functions.invoke(
                "generate-brain-hack",
                options: FunctionInvokeOptions(body: HackRequest(userId: userId))
            )
            
            isTodayHackComplete = response.isCompleted ?? false
            print("✅ Today's completion status preloaded: \(isTodayHackComplete)")
            
        } catch {
            isTodayHackComplete = false
            print("❌ Completion status fetch error: \(error)")
        }
    }
    
    /// Clears cached data (useful for testing or sign out)
    func clearCache() {
        meterData = nil
        isTodayHackComplete = false
        lastFetchDate = nil
        errorMessage = nil
    }
}
