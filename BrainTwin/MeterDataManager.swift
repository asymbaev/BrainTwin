import Foundation
import SwiftUI
import Supabase
import Combine

/// Shared manager that preloads and caches meter data AND daily hack
/// This eliminates duplicate API calls and ensures data is ready before user reaches dashboard
@MainActor
final class MeterDataManager: ObservableObject {
    static let shared = MeterDataManager()
    
    @Published var meterData: MeterResponse?
    @Published var todaysHack: BrainHack?  // ← NEW: Cache the full hack data
    @Published var isTodayHackComplete = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastFetchDate: Date?
    @Published var lastHackFetchDate: Date?  // ← NEW: Track hack fetch separately
    
    private let supabase = SupabaseManager.shared
    
    private init() {}
    
    /// Fetches meter data AND today's complete hack data
    /// Call this early (e.g., during animation) to preload data
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

        // Fetch both meter data and complete hack in parallel
        async let meterTask: () = fetchMeter(userId: userId)
        async let hackTask: () = fetchTodaysHack(userId: userId)

        // Wait for both
        await meterTask
        await hackTask

        lastFetchDate = Date()
        lastHackFetchDate = Date()
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
    
    private func fetchTodaysHack(userId: String) async {
        do {
            struct HackRequest: Encodable { let userId: String }

            // Full hack response structure
            struct HackResponse: Decodable {
                let hackName: String
                let quote: String
                let explanation: String
                let neuroscience: String
                let personalization: String?
                let barrier: String
                let isCompleted: Bool?
                let audioUrls: [String]?
            }

            let response: HackResponse = try await supabase.client.functions.invoke(
                "generate-brain-hack",
                options: FunctionInvokeOptions(body: HackRequest(userId: userId))
            )

            // Cache the complete hack data
            todaysHack = BrainHack(
                hackName: response.hackName,
                quote: response.quote,
                explanation: response.explanation,
                neuroscience: response.neuroscience,
                personalization: response.personalization,
                barrier: response.barrier,
                isCompleted: response.isCompleted ?? false,
                audioUrls: response.audioUrls
            )

            isTodayHackComplete = response.isCompleted ?? false

            print("✅ Today's hack preloaded: \(response.hackName)")
            print("   Completion status: \(isTodayHackComplete)")
            print("   Audio URLs: \(response.audioUrls?.count ?? 0) files")

        } catch {
            todaysHack = nil
            isTodayHackComplete = false
            print("❌ Hack fetch error: \(error)")
        }
    }
    
    /// Clears cached data (useful for testing or sign out)
    func clearCache() {
        meterData = nil
        todaysHack = nil
        isTodayHackComplete = false
        lastFetchDate = nil
        lastHackFetchDate = nil
        errorMessage = nil
    }
}
