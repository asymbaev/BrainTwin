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
        
        do {
            print("🧠 Loading today's hack (instant)...")
            
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
            
            print("✅ Hack loaded instantly!")
            print("🎵 Audio URLs:", response.audioUrls ?? [])
            
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
        guard let userId = supabase.userId, !hasMarkedComplete else { return }
        
        do {
            let today = ISO8601DateFormatter().string(from: Date()).split(separator: "T")[0]
            let now = ISO8601DateFormatter().string(from: Date())
            
            struct UpdateTask: Encodable {
                let completed_at: String
            }
            
            let update = UpdateTask(completed_at: now)
            
            // Step 1: Mark the daily task as complete
            try await supabase.client
                .from("daily_tasks")
                .update(update)
                .eq("user_id", value: userId)
                .eq("date", value: String(today))
                .execute()
            
            print("✅ Daily task marked complete!")
            
            hasMarkedComplete = true
            
            // Step 2: Call calculate-meter to update rewire progress
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
            
            // Step 3: CRITICAL FIX - Force refresh MeterDataManager
            await MeterDataManager.shared.fetchMeterData(force: true)
            
            // Step 4: Notify Dashboard to refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshDashboard"), object: nil)
            
            print("🔄 Dashboard refresh triggered!")
            
        } catch {
            print("❌ Mark complete error: \(error)")
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
