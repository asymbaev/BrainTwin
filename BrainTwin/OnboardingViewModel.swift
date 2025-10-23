import Foundation
import Supabase
import Combine

@MainActor
class OnboardingViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var mainGoal = ""
    @Published var isLoading = false
    
    private let supabase = SupabaseManager.shared
    
    let suggestedGoals = [
        "Build discipline to finish my startup tasks",
        "Reduce stress while coding",
        "Improve focus for deep work",
        "Stop procrastinating on important projects",
        "Develop consistent work habits"
    ]
    
    func saveGoal() async {
        guard let userId = supabase.userId else { return }
        
        isLoading = true
        
        do {
            struct UpdateGoal: Encodable {
                let main_goal: String
            }
            
            let update = UpdateGoal(main_goal: mainGoal)
            
            try await supabase.client
                .from("users")
                .update(update)
                .eq("id", value: userId)
                .execute()
            
            print("✅ Goal saved: \(mainGoal)")
            
            // Just update the step, View will handle animation
            currentStep = 2
            
        } catch {
            print("❌ Save goal error: \(error)")
        }
        
        isLoading = false
    }
}
