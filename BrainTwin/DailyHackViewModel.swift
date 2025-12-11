import Foundation
import Supabase
import Combine
import AVFoundation

@MainActor
class DailyHackViewModel: ObservableObject {
    @Published var todaysHack: BrainHack?
    @Published var isSpeaking = false
    @Published var errorMessage: String?
    @Published var showSuccessAlert = false
    @Published var hasMarkedComplete = false
    @Published var todaysProgress: Double?
    
    private let supabase = SupabaseManager.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    init(preloadedHack: BrainHack? = nil) {
        if let hack = preloadedHack {
            self.todaysHack = hack
            self.hasMarkedComplete = hack.isCompleted ?? false
        }
    }
    
    func loadTodaysHack() async {
        guard let userId = supabase.userId else {
            errorMessage = "No user ID found"
            return
        }
        
        // ✅ FIRST: Check if data was already pre-fetched during animation
        let meterManager = MeterDataManager.shared
        
        if let cachedHack = meterManager.todaysHack,
           let lastFetch = meterManager.lastHackFetchDate,
           Date().timeIntervalSince(lastFetch) < 300 {  // Cache valid for 5 minutes
            
            print("⚡️ Using pre-fetched hack (loaded during animation) - INSTANT!")
            print("🔍 [DEBUG] Cached hack isCompleted: \(cachedHack.isCompleted ?? false)")
            todaysHack = cachedHack
            hasMarkedComplete = cachedHack.isCompleted ?? false
            print("🔍 [DEBUG] hasMarkedComplete set to: \(hasMarkedComplete)")
            
            // Use cached meter data for progress
            if let cachedMeter = meterManager.meterData {
                todaysProgress = cachedMeter.progress
            }
            
            return
        }
        
        // ❌ Cache miss: Fetch from backend (shouldn't happen if pre-fetch worked)
        print("⚠️ Cache miss - fetching hack from backend (pre-fetch may have failed)")
        
        do {
            struct HackRequest: Encodable {
                let userId: String
            }
            
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
            
            let request = HackRequest(userId: userId)
            
            let response: HackResponse = try await supabase.client.functions.invoke(
                "generate-brain-hack",
                options: FunctionInvokeOptions(body: request)
            )
            
            todaysHack = BrainHack(
                hackName: response.hackName,
                quote: response.quote,
                explanation: response.explanation,
                neuroscience: response.neuroscience,
                personalization: response.personalization,
                barrier: response.barrier,
                isCompleted: response.isCompleted,
                audioUrls: response.audioUrls
            )
            
            hasMarkedComplete = response.isCompleted ?? false

            print("✅ Hack loaded from backend")
            print("🔍 [DEBUG] Backend returned isCompleted: \(response.isCompleted ?? false)")
            print("🔍 [DEBUG] hasMarkedComplete set to: \(hasMarkedComplete)")
            
            // Get today's progress for display
            let meterResponse: MeterResponse = try await supabase.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: HackRequest(userId: userId))
            )

            todaysProgress = meterResponse.progress
            
        } catch {
            print("❌ Load error: \(error)")
            errorMessage = "Failed to load hack: \(error.localizedDescription)"
        }
    }
    
    func markAsComplete() async {
        print("🔵 [DEBUG] markAsComplete() called")
        print("   userId: \(supabase.userId ?? "nil")")
        print("   hasMarkedComplete: \(hasMarkedComplete)")

        guard let userId = supabase.userId else {
            print("❌ [DEBUG] No user ID - ABORTING")
            return
        }

        guard !hasMarkedComplete else {
            print("⚠️ [DEBUG] Already marked complete - SKIPPING")
            print("   This hack was loaded as isCompleted=true from backend!")
            return
        }

        print("✅ [DEBUG] Proceeding with completion...")

        do {
            let today = ISO8601DateFormatter().string(from: Date()).split(separator: "T")[0]
            let now = ISO8601DateFormatter().string(from: Date())
            
            struct UpdateTask: Encodable {
                let completed_at: String
            }
            
            let update = UpdateTask(completed_at: now)
            
            // Step 1: Mark the daily task as complete in database
            try await supabase.client
                .from("daily_tasks")
                .update(update)
                .eq("user_id", value: userId)
                .eq("date", value: String(today))
                .execute()
            
            print("✅ Daily task marked complete in DB!")
            
            // Step 2: IMMEDIATELY update local state (don't wait for refetch)
            hasMarkedComplete = true
            await MainActor.run {
                MeterDataManager.shared.isTodayHackComplete = true
            }
            print("✅ Local completion state updated immediately")
            
            // Step 3: Save completion date for check-in logic
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let todayString = formatter.string(from: Date())
            UserDefaults.standard.set(todayString, forKey: "lastHackCompletionDate")
            print("✅ Saved completion date: \(todayString)")
            
            // Step 4: Wait briefly for backend consistency (Supabase replication)
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            print("⏱️ Waited for backend consistency...")
            
            // Step 5: Refetch meter data to get updated progress/streak
            struct MeterRequest: Encodable {
                let userId: String
            }
            
            let meterRequest = MeterRequest(userId: userId)
            let meterResponse: MeterResponse = try await supabase.client.functions.invoke(
                "calculate-meter",
                options: FunctionInvokeOptions(body: meterRequest)
            )
            
            todaysProgress = meterResponse.progress
            
            print("📊 Rewire meter updated!")
            print("   Progress: \(meterResponse.progress)%")
            print("   Skill: \(meterResponse.skillLevel)")
            print("   Streak: \(meterResponse.streak) days")
            
            // Step 6: Force refresh MeterDataManager with new data
            await MeterDataManager.shared.fetchMeterData(force: true)
            print("🔄 MeterDataManager refreshed with latest data")
            
            // Step 7: FINALLY - Notify Dashboard to refresh UI
            await MainActor.run {
                NotificationCenter.default.post(name: Notification.Name("RefreshDashboard"), object: nil)
            }
            print("📢 Dashboard refresh notification sent!")
            
        } catch {
            print("❌ Mark complete error: \(error)")
            // Rollback local state on error
            hasMarkedComplete = false
            await MainActor.run {
                MeterDataManager.shared.isTodayHackComplete = false
            }
        }
    }
    
    func toggleSpeech(text: String) {
        if isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        } else {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            utterance.rate = 0.5
            speechSynthesizer.speak(utterance)
            isSpeaking = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(text.count) / 10) {
                self.isSpeaking = false
            }
        }
    }
}
